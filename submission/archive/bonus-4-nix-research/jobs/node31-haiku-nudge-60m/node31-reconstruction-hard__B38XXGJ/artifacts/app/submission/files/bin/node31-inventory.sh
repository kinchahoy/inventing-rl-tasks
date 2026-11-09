out=/var/lib/prometheus/node-exporter
users=$(awk -F: '$3 >= 1000 && $7 ~ /bash$/ {n++} END {print n+0}' /etc/passwd)
{
  echo '# TYPE node31_inventory_users gauge'
  echo "node31_inventory_users $users"
  echo '# TYPE node31_inventory_info gauge'
  echo 'node31_inventory_info{role="monitor"} 1'
} > "$out/node31_inventory.prom.tmp"
mv "$out/node31_inventory.prom.tmp" "$out/node31_inventory.prom"
