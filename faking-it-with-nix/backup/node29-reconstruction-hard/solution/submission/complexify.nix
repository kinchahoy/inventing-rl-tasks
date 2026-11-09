# Oracle side of the complexifiers (author/complexify.md); the original recipe is replica.nix.
{ ... }: {
  # Fragments spliced into the exim configuration by replica.nix.
  _module.args.cx = {
    # CX-auth-after-tls: AUTH is advertised only inside a TLS session.
    # CX-submission-sender-match: a mail-from ACL ties the envelope sender to the login.
    eximMain = ''
      auth_advertise_hosts = ''${if eq{$tls_in_cipher}{}{}{*}}
      acl_smtp_mail = acl_check_mail
    '';
    eximAcl = ''
      acl_check_mail:
        deny   authenticated = *
               condition = ''${if eq{''${lc:$sender_address}}{''${lc:$authenticated_id}@n29.test}{no}{yes}}
               message = Sender address does not match the authenticated user
        accept
    '';
  };
  # CX-conf-d-decoy: nothing to reproduce; the split-config files on the reference are never read.
}
