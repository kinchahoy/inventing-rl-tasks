"""Worker-side adapter: builds the objects for one invocation and encodes results.

Contains no case generators, pools, seeds, thresholds, or checks. It is readable by the submitted
code and is also used unchanged by the trusted parent and the reference worker.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any

_META_FIELDS = (
    "empty", "line", "column", "start_pos", "end_line", "end_column", "end_pos",
    "container_line", "container_column", "container_end_line", "container_end_column",
    "container_start_pos", "container_end_pos", "orig_expansion", "match_tree",
)


def _recording_tree_transformer(trace: list[tuple[Any, ...]], resolve: bool) -> Any:
    from lark.parsers.earley_forest import TreeForestTransformer
    from lark.tree import Tree

    class RecordingTransformer(TreeForestTransformer):
        def __init__(self) -> None:
            super().__init__(tree_class=Tree, resolve_ambiguity=resolve, use_cache=False)

        def __default__(self, name: str, data: list[Any]) -> Any:
            trace.append(("rule", name))
            return Tree(name, data)

        def __default_ambig__(self, name: str, data: list[Any]) -> Any:
            trace.append(("ambiguity", name, len(data)))
            return super().__default_ambig__(name, data)

        def __default_token__(self, node: Any) -> Any:
            trace.append(("token", node.type, node.value))
            return node

    return RecordingTransformer()


def _recording_visitor(trace: list[tuple[Any, ...]], single_visit: bool) -> Any:
    from lark.parsers.earley_forest import ForestVisitor

    class RecordingVisitor(ForestVisitor):
        def __init__(self) -> None:
            super().__init__(single_visit=single_visit)

        def visit_token_node(self, node: Any) -> None:
            trace.append(("token", node.type, node.value))

        def visit_symbol_node_in(self, node: Any) -> Any:
            trace.append(("symbol_in", node.s.name, node.start, node.end))
            return node.children

        def visit_symbol_node_out(self, node: Any) -> None:
            trace.append(("symbol_out", node.s.name, node.start, node.end))

        def visit_intermediate_node_in(self, node: Any) -> Any:
            trace.append(("intermediate_in", node.start, node.end))
            return node.children

        def visit_intermediate_node_out(self, node: Any) -> None:
            trace.append(("intermediate_out", node.start, node.end))

        def visit_packed_node_in(self, node: Any) -> Any:
            trace.append(("packed_in", node.start))
            return node.children

        def visit_packed_node_out(self, node: Any) -> None:
            trace.append(("packed_out", node.start))

        def on_cycle(self, node: Any, path: list[Any]) -> None:
            trace.append(("cycle", type(node).__name__, len(path)))

    return RecordingVisitor()


def _recording_callbacks(callbacks: Mapping[Any, Callable[..., Any]], trace: list[tuple[Any, ...]]) -> dict[Any, Callable[..., Any]]:
    wrapped = {}
    for rule, callback in callbacks.items():
        def record_callback(data: list[Any], rule: Any = rule, callback: Callable[..., Any] = callback) -> Any:
            trace.append(("callback", rule.origin.name, rule.alias))
            return callback(data)

        wrapped[rule] = record_callback
    return wrapped


def _forest_snapshot(root: Any) -> list[Any]:
    from lark.parsers.earley_forest import PackedNode, SymbolNode, TokenNode

    pending = [root]
    seen: set[int] = set()
    snapshot = []
    while pending:
        node = pending.pop()
        if node is None or id(node) in seen:
            continue
        seen.add(id(node))
        if isinstance(node, TokenNode):
            snapshot.append(("token", _encode_value(node.token), _encode_value(node.priority)))
            children = ()
        elif isinstance(node, SymbolNode):
            name = node.s[0].origin.name if node.is_intermediate else node.s.name
            snapshot.append(("symbol", str(name), node.start, node.end, _encode_value(node.priority)))
            children = node.children
        elif isinstance(node, PackedNode):
            snapshot.append(("packed", str(node.rule.origin.name), node.rule.order, node.start, _encode_value(node.priority)))
            children = node.children
        else:
            raise TypeError(f"unexpected forest node {type(node).__name__}")
        pending.extend(reversed(children))
    return snapshot


def _encode_value(value: Any) -> Any:
    """Convert results to stable JSON-compatible, type-aware values."""
    from lark.lexer import Token
    from lark.tree import Tree

    if isinstance(value, Token):
        return {
            "kind": "token", "class": f"{type(value).__module__}.{type(value).__qualname__}",
            "type": value.type,
            "value": _encode_value(value.value),
            "positions": {
                name: getattr(value, name)
                for name in ("start_pos", "line", "column", "end_line", "end_column", "end_pos")
            },
        }
    if isinstance(value, Tree):
        meta = getattr(value, "_meta", None)
        metadata = None
        if meta is not None:
            names = set(vars(meta))
            names.update(name for name in _META_FIELDS if hasattr(meta, name))
            metadata = {name: _encode_value(getattr(meta, name)) for name in sorted(names)}
        return {
            "kind": "tree", "class": f"{type(value).__module__}.{type(value).__qualname__}",
            "data": _encode_value(value.data),
            "children_type": type(value.children).__name__,
            "children": [_encode_value(child) for child in value.children],
            "meta": metadata,
        }
    if isinstance(value, float):
        return {"kind": "float", "hex": value.hex()}
    if value is None or isinstance(value, (str, int, bool)):
        return value
    if isinstance(value, bytes):
        return {"kind": "bytes", "hex": value.hex()}
    if isinstance(value, Mapping):
        items = [(_encode_value(key), _encode_value(item)) for key, item in value.items()]
        return {str(key): item for key, item in sorted(items, key=lambda pair: str(pair[0]))}
    if isinstance(value, (tuple, list)):
        return {"kind": type(value).__name__, "items": [_encode_value(item) for item in value]}
    if isinstance(value, (set, frozenset)):
        values = [_encode_value(item) for item in value]
        return {"kind": type(value).__name__, "items": sorted(values, key=repr)}
    return {"kind": "object", "type": f"{type(value).__module__}.{type(value).__qualname__}", "repr": repr(value)}


def encode(result: Any) -> Any:
    return _encode_value(result)


def _trace_snapshot(trace: list[tuple[Any, ...]]) -> dict[str, Any]:
    return {"trace": _encode_value(trace)}


def _observe_forest(
    operation: Callable[[], Any], root: Any, trace: list[tuple[Any, ...]],
) -> tuple[Callable[[], Any], Callable[[], Any]]:
    called = False

    def invoke() -> Any:
        nonlocal called
        try:
            return operation()
        finally:
            called = True

    def snapshot() -> Any:
        # Traversing children can materialize lazy paths. Never do this before timing.
        return {"forest": _forest_snapshot(root) if called else None, **_trace_snapshot(trace)}

    return invoke, snapshot


def prepare(case: dict[str, Any]) -> tuple[Callable[[], Any], Callable[[], Any]]:
    from lark import Lark

    if case["kind"] == "parse":
        text = case["text"]
        parser = Lark(
            case["grammar"],
            parser="earley",
            ambiguity=case["ambiguity"],
            **{"propagate_positions": True, "start": case.get("starts", "start"), **case.get("options", {})},
        )
        start = case.get("start")
        return lambda: parser.parse(text, start=start), lambda: {"input": text}

    forest_parser = Lark(
        case["grammar"], parser="earley", ambiguity="forest", propagate_positions=True
    )
    root = forest_parser.parse(case["text"])
    if case["kind"] == "forest_visit":
        trace: list[tuple[Any, ...]] = []
        visitor = _recording_visitor(trace, case["single_visit"])
        return _observe_forest(lambda: visitor.visit(root), root, trace)

    trace: list[tuple[Any, ...]] = []
    if case["transformer"] == "parse_tree":
        from lark.parsers.earley_forest import ForestToParseTree

        callback_parser = Lark(
            case["grammar"], parser="earley", ambiguity="resolve", propagate_positions=True
        )
        callbacks = callback_parser.parser.parser.callbacks
        if case.get("record_trace", False):
            callbacks = _recording_callbacks(callbacks, trace)
        transformer = ForestToParseTree(
            callbacks=callbacks, resolve_ambiguity=True, use_cache=False
        )
    else:
        if case.get("record_trace", False):
            transformer = _recording_tree_transformer(trace, resolve=True)
        else:
            from lark.parsers.earley_forest import TreeForestTransformer

            transformer = TreeForestTransformer(resolve_ambiguity=True, use_cache=False)
    return _observe_forest(lambda: transformer.transform(root), root, trace)
