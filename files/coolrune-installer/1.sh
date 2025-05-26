#!/bin/bash
su -c '
# ========================================================
# Enhanced Performance-Aware System Hardening Script for Arch Linux
# Optimized for gaming PCs with P2P, gaming, and developer needs
# Focus: Maximum security with minimal performance impact
# ========================================================

# Performance monitoring functions
check_cpu_cores() {
    nproc
}

check_ram_gb() {
    free -g | awk "NR==2{printf \"%.0f\", \$2}"
}

# Set performance-aware limits based on system specs
CPU_CORES=$(check_cpu_cores)
RAM_GB=$(check_ram_gb)

# Calculate optimal limits based on hardware
if [ "$CPU_CORES" -ge 8 ] && [ "$RAM_GB" -ge 16 ]; then
    CONN_LIMIT="200"
    RATE_LIMIT="10/s"
    BURST_LIMIT="20"
    LOG_LIMIT="10/min"
elif [ "$CPU_CORES" -ge 4 ] && [ "$RAM_GB" -ge 8 ]; then
    CONN_LIMIT="150"
    RATE_LIMIT="7/s"
    BURST_LIMIT="15"
    LOG_LIMIT="7/min"
else
    CONN_LIMIT="100"
    RATE_LIMIT="5/s"
    BURST_LIMIT="10"
    LOG_LIMIT="5/min"
fi

echo "System specs detected: ${CPU_CORES} cores, ${RAM_GB}GB RAM"
echo "Performance limits set: ${CONN_LIMIT} connections, ${RATE_LIMIT} rate limit"

# Function for applying config files with improved error handling
apply_config() {
    local source_file="confs/$1"
    local target_file="$2"
    
    if [ ! -f "$source_file" ]; then
        echo "Warning: Configuration file $source_file not found - skipping"
        return 0
    fi
    
    if ! cat "$source_file" > "$target_file" 2>/dev/null; then
        echo "Warning: Failed to apply $source_file to $target_file - skipping"
        return 0
    fi
    
    echo "Successfully applied $source_file to $target_file"
    return 0
}

# Print section header for better readability
print_section() {
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
}

print_section "Starting performance-aware system hardening..."

# ========================================================
# PERFORMANCE-OPTIMIZED KERNEL PARAMETERS
# ========================================================
print_section "Optimizing kernel parameters for security and performance..."

# Backup original sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup

# Enhanced TCP/IP hardening with performance optimizations
cat >> /etc/sysctl.conf << EOF
# ==============================================
# Performance-Aware Security Settings
# ==============================================

# Network Performance Optimization
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.core.somaxconn = 1024

# TCP Performance with Security
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# Enhanced Security Settings
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable redirects and source routing
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# IPv6 Security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Memory and Process Protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.perf_event_paranoid = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# File System Security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 0

# Performance-aware connection tracking
net.netfilter.nf_conntrack_max = $((CONN_LIMIT * 100))
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120

# Gaming and P2P optimizations
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_keepalive_probes = 7
net.ipv4.tcp_keepalive_intvl = 30

# Disable unnecessary protocols
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF

# Apply sysctl settings immediately
sysctl -p

# ========================================================
# ENHANCED FILE PERMISSIONS WITH PERFORMANCE CONSIDERATION
# ========================================================
print_section "Setting secure file permissions with performance optimization..."

# Critical system files
chmod 700 /root
chmod 600 /etc/shadow
chmod 600 /etc/gshadow
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 600 /etc/sudoers
chmod -R 700 /etc/ssl/private
chmod -R 755 /etc/ssl/certs

# Optimize cron permissions (batch operation)
find /etc/cron.* -type f -print0 | xargs -0 chmod 0700
chmod 0600 /etc/crontab
chmod 0600 /etc/ssh/sshd_config 2>/dev/null

# Additional hardening for sensitive directories
chmod 750 /home 2>/dev/null
chmod 750 /var/log 2>/dev/null
chmod 640 /var/log/auth.log 2>/dev/null
chmod 640 /var/log/syslog 2>/dev/null

# ========================================================
# PERFORMANCE-OPTIMIZED UFW CONFIGURATION
# ========================================================
print_section "Configuring performance-optimized UFW..."

# Reset UFW to clean state
ufw --force reset

# Configure UFW with performance optimizations
ufw default deny incoming
ufw default allow outgoing

# Essential services with rate limiting
ufw limit 22/tcp comment "SSH with rate limiting"
ufw allow 80/tcp comment "HTTP"
ufw allow 443/tcp comment "HTTPS"

# Gaming and P2P (optimized ranges)
ufw allow 6881:6889/tcp comment "BitTorrent TCP"
ufw allow 6881:6889/udp comment "BitTorrent UDP"
ufw allow 27000:27100/tcp comment "Steam TCP"
ufw allow 27000:27100/udp comment "Steam UDP"
ufw allow 3478:3480/tcp comment "PlayStation/Xbox TCP"
ufw allow 3478:3480/udp comment "PlayStation/Xbox UDP"

# Discord and VoIP (performance-critical)
ufw allow 50000:65535/udp comment "Discord/VoIP UDP"

# Developer tools
ufw allow 9418/tcp comment "Git protocol"
ufw allow out 22/tcp comment "Git SSH outbound"

# Tor network
ufw allow 9050/tcp comment "Tor SOCKS"
ufw allow 9051/tcp comment "Tor control"
ufw allow 9150/tcp comment "Tor browser"

# Enable UFW
ufw --force enable

# ========================================================
# PERFORMANCE-OPTIMIZED IPTABLES CONFIGURATION
# ========================================================
print_section "Configuring performance-optimized iptables..."

# Initialize variables
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
SSHPORT="22"

# Performance-aware logging
LOG="LOG --log-level 4 --log-tcp-sequence --log-tcp-options"
LOG="$LOG --log-ip-options"

# Optimized rate limiting
RLIMIT="-m limit --limit $RATE_LIMIT --limit-burst $BURST_LIMIT"

# Load connection tracking modules
modprobe nf_conntrack
modprobe nf_conntrack_ftp
modprobe nf_conntrack_irc

# Set performance-aware policies
"$IPTABLES" -P INPUT DROP
"$IPTABLES" -P FORWARD DROP
"$IPTABLES" -P OUTPUT ACCEPT

# Configure NAT/mangle for performance
"$IPTABLES" -t nat -P PREROUTING ACCEPT
"$IPTABLES" -t nat -P OUTPUT ACCEPT
"$IPTABLES" -t nat -P POSTROUTING ACCEPT
"$IPTABLES" -t mangle -P PREROUTING ACCEPT
"$IPTABLES" -t mangle -P INPUT ACCEPT
"$IPTABLES" -t mangle -P FORWARD ACCEPT
"$IPTABLES" -t mangle -P OUTPUT ACCEPT
"$IPTABLES" -t mangle -P POSTROUTING ACCEPT

# Flush existing rules
"$IPTABLES" -F
"$IPTABLES" -t nat -F
"$IPTABLES" -t mangle -F
"$IPTABLES" -X
"$IPTABLES" -t nat -X
"$IPTABLES" -t mangle -X

# ========================================================
# PERFORMANCE-OPTIMIZED CUSTOM CHAINS
# ========================================================
print_section "Creating performance-optimized logging chains..."

# Efficient logging chains with performance limits
"$IPTABLES" -N ACCEPTLOG
"$IPTABLES" -A ACCEPTLOG -m limit --limit $LOG_LIMIT -j "$LOG" --log-prefix "ACCEPT "
"$IPTABLES" -A ACCEPTLOG -j ACCEPT

"$IPTABLES" -N DROPLOG
"$IPTABLES" -A DROPLOG -m limit --limit $LOG_LIMIT -j "$LOG" --log-prefix "DROP "
"$IPTABLES" -A DROPLOG -j DROP

"$IPTABLES" -N REJECTLOG
"$IPTABLES" -A REJECTLOG -m limit --limit $LOG_LIMIT -j "$LOG" --log-prefix "REJECT "
"$IPTABLES" -A REJECTLOG -p tcp -j REJECT --reject-with tcp-reset
"$IPTABLES" -A REJECTLOG -j REJECT

# Optimized ICMP handling
"$IPTABLES" -N ICMP_CHECK
"$IPTABLES" -A ICMP_CHECK -p icmp --icmp-type destination-unreachable -j ACCEPT
"$IPTABLES" -A ICMP_CHECK -p icmp --icmp-type time-exceeded -j ACCEPT
"$IPTABLES" -A ICMP_CHECK -p icmp --icmp-type parameter-problem -j ACCEPT
"$IPTABLES" -A ICMP_CHECK -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 2 -j ACCEPT
"$IPTABLES" -A ICMP_CHECK -j DROPLOG

# Performance-critical connection tracking
"$IPTABLES" -N CONNTRACK_CHECK
"$IPTABLES" -A CONNTRACK_CHECK -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
"$IPTABLES" -A CONNTRACK_CHECK -m conntrack --ctstate INVALID -j DROPLOG

# ========================================================
# ESSENTIAL TRAFFIC RULES (PERFORMANCE OPTIMIZED)
# ========================================================
print_section "Configuring essential traffic rules..."

# Loopback (critical for performance)
"$IPTABLES" -A INPUT -i lo -j ACCEPT
"$IPTABLES" -A OUTPUT -o lo -j ACCEPT

# Connection tracking (performance critical - place early)
"$IPTABLES" -A INPUT -j CONNTRACK_CHECK
"$IPTABLES" -A OUTPUT -j CONNTRACK_CHECK

# ICMP handling
"$IPTABLES" -A INPUT -p icmp -j ICMP_CHECK
"$IPTABLES" -A OUTPUT -p icmp -j ACCEPT

# ========================================================
# ADVANCED ATTACK PREVENTION WITH PERFORMANCE AWARENESS
# ========================================================
print_section "Implementing advanced attack prevention..."

# Efficient packet validation
"$IPTABLES" -A INPUT -p tcp --tcp-flags ALL NONE -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags ALL ALL -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROPLOG

# Performance-aware SYN flood protection
"$IPTABLES" -A INPUT -p tcp --syn -m connlimit --connlimit-above $CONN_LIMIT -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --syn -m limit --limit $RATE_LIMIT --limit-burst $BURST_LIMIT -j ACCEPT

# Advanced brute force protection for SSH
"$IPTABLES" -A INPUT -p tcp --dport $SSHPORT -m conntrack --ctstate NEW -m recent --set --name SSH
"$IPTABLES" -A INPUT -p tcp --dport $SSHPORT -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 3 --name SSH -j DROPLOG

# Port scan detection (performance optimized)
"$IPTABLES" -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROPLOG
"$IPTABLES" -A INPUT -m recent --name portscan --remove
"$IPTABLES" -A INPUT -p tcp --tcp-flags ALL NONE -m recent --name portscan --set -j DROPLOG

# ========================================================
# GAMING AND P2P OPTIMIZATIONS
# ========================================================
print_section "Optimizing gaming and P2P performance..."

# Gaming services (high priority)
"$IPTABLES" -A INPUT -p tcp --dport 27000:27100 -m conntrack --ctstate NEW -j ACCEPT
"$IPTABLES" -A INPUT -p udp --dport 27000:27100 -j ACCEPT
"$IPTABLES" -A INPUT -p tcp --dport 3478:3480 -j ACCEPT
"$IPTABLES" -A INPUT -p udp --dport 3478:3480 -j ACCEPT

# Discord and VoIP (performance critical)
"$IPTABLES" -A INPUT -p udp --dport 50000:65535 -m conntrack --ctstate NEW -j ACCEPT
"$IPTABLES" -A OUTPUT -p udp --dport 50000:65535 -j ACCEPT

# P2P with connection limits
"$IPTABLES" -A INPUT -p tcp --dport 6881:6889 -m connlimit --connlimit-above 50 -j DROPLOG
"$IPTABLES" -A INPUT -p tcp --dport 6881:6889 -j ACCEPT
"$IPTABLES" -A INPUT -p udp --dport 6881:6889 -j ACCEPT

# ========================================================
# DEVELOPER AND ESSENTIAL SERVICES
# ========================================================
print_section "Configuring developer and essential services..."

# Essential outbound connections
"$IPTABLES" -A OUTPUT -p udp --dport 53 -j ACCEPT  # DNS
"$IPTABLES" -A OUTPUT -p tcp --dport 53 -j ACCEPT  # DNS over TCP
"$IPTABLES" -A OUTPUT -p tcp --dport 80 -j ACCEPT  # HTTP
"$IPTABLES" -A OUTPUT -p tcp --dport 443 -j ACCEPT # HTTPS
"$IPTABLES" -A OUTPUT -p tcp --dport 22 -j ACCEPT  # SSH
"$IPTABLES" -A OUTPUT -p tcp --dport 587 -j ACCEPT # SMTP TLS
"$IPTABLES" -A OUTPUT -p tcp --dport 993 -j ACCEPT # IMAP TLS
"$IPTABLES" -A OUTPUT -p tcp --dport 995 -j ACCEPT # POP3 TLS

# Developer tools
"$IPTABLES" -A OUTPUT -p tcp --dport 9418 -j ACCEPT # Git protocol
"$IPTABLES" -A INPUT -p tcp --sport 9418 -j ACCEPT

# Tor network (privacy-focused)
"$IPTABLES" -A INPUT -p tcp --dport 9050 -j ACCEPT
"$IPTABLES" -A INPUT -p tcp --dport 9051 -j ACCEPT
"$IPTABLES" -A INPUT -p tcp --dport 9150 -j ACCEPT
"$IPTABLES" -A OUTPUT -p tcp --dport 9050 -j ACCEPT
"$IPTABLES" -A OUTPUT -p tcp --dport 9051 -j ACCEPT
"$IPTABLES" -A OUTPUT -p tcp --dport 9150 -j ACCEPT

# Essential inbound services
"$IPTABLES" -A INPUT -p tcp --dport 80 -j ACCEPT
"$IPTABLES" -A INPUT -p tcp --dport 443 -j ACCEPT
"$IPTABLES" -A INPUT -p tcp --dport $SSHPORT -j ACCEPT

# ========================================================
# FINAL RULES AND CLEANUP
# ========================================================
print_section "Applying final rules and cleanup..."

# Log remaining dropped packets (with performance limits)
"$IPTABLES" -A INPUT -m limit --limit $LOG_LIMIT -j LOG --log-prefix "INPUT_DROP: " --log-level 4
"$IPTABLES" -A FORWARD -m limit --limit $LOG_LIMIT -j LOG --log-prefix "FORWARD_DROP: " --log-level 4

# Final drop rules
"$IPTABLES" -A INPUT -j DROP
"$IPTABLES" -A FORWARD -j DROP

# Save iptables rules
mkdir -p /etc/iptables
iptables-save > /etc/iptables/iptables.rules

# ========================================================
# ENHANCED SECURITY MODULES
# ========================================================
print_section "Configuring enhanced security modules..."

# Disable uncommon network protocols (performance-aware)
cat > /etc/modprobe.d/blacklist-uncommon.conf << EOF
# Uncommon network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install n-hdlc /bin/true
install ax25 /bin/true
install netrom /bin/true
install x25 /bin/true
install rose /bin/true
install decnet /bin/true
install econet /bin/true
install af_802154 /bin/true
install ipx /bin/true
install appletalk /bin/true
install psnap /bin/true
install p8023 /bin/true
install p8022 /bin/true
install can /bin/true
install atm /bin/true

# Uncommon filesystems
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true

# Disable firewire and thunderbolt (security risk)
install firewire-core /bin/true
install firewire-ohci /bin/true
install firewire-sbp2 /bin/true
install thunderbolt /bin/true
EOF

# ========================================================
# PERFORMANCE MONITORING AND OPTIMIZATION
# ========================================================
print_section "Setting up performance monitoring..."

# Create performance monitoring script
cat > /usr/local/bin/security-performance-check << EOF
#!/bin/bash
# Performance monitoring for security measures

echo "=== Security Performance Report ==="
echo "Date: \$(date)"
echo "CPU Cores: \$(nproc)"
echo "Memory: \$(free -h | grep Mem: | awk '{print \$2}')"
echo ""

# Network connections
echo "Active connections: \$(netstat -tn | grep ESTABLISHED | wc -l)"
echo "Total tracked connections: \$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 'N/A')"
echo "Max tracked connections: \$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 'N/A')"
echo ""

# Firewall stats
echo "Iptables rules count: \$(iptables -L | grep -c '^Chain')"
echo "Recent dropped packets: \$(dmesg | grep -c 'DROP' | tail -1)"
echo ""

# System load
echo "Current load: \$(uptime | awk -F'load average:' '{print \$2}')"
echo "Memory usage: \$(free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}')"
EOF

chmod +x /usr/local/bin/security-performance-check

# ========================================================
# ADVANCED AUTHENTICATION HARDENING
# ========================================================
print_section "Implementing advanced authentication hardening..."

# Enhanced PAM configuration for performance
if ! grep -q "auth required pam_wheel.so" /etc/pam.d/su; then
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su
fi

# Secure bash history with performance optimization
cat > /etc/profile.d/secure-history.sh << EOF
# Secure bash history configuration
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=ignoreboth:erasedups
export HISTSIZE=2000
export HISTFILESIZE=10000
readonly HISTFILE
readonly HISTFILESIZE
shopt -s histappend
shopt -s cmdhist
EOF
chmod +x /etc/profile.d/secure-history.sh

# Create enhanced login banner
cat > /etc/issue << EOF
╔═══════════════════════════════════════════════════════════════════╗
║                        SECURITY NOTICE                           ║
║                                                                   ║
║  This system is for authorized users only. All activities        ║
║  are logged and monitored. Unauthorized access is prohibited     ║
║  and will be prosecuted to the full extent of the law.          ║
║                                                                   ║
║  Disconnect immediately if you are not authorized!               ║
╚═══════════════════════════════════════════════════════════════════╝
EOF

cp /etc/issue /etc/issue.net

# ========================================================
# SYSTEM INTEGRITY AND MONITORING
# ========================================================
print_section "Setting up system integrity monitoring..."

# Create system integrity check script
cat > /usr/local/bin/integrity-check << EOF
#!/bin/bash
# System integrity monitoring

INTEGRITY_LOG="/var/log/integrity-check.log"
DATE=\$(date)

echo "[\$DATE] Starting integrity check..." >> \$INTEGRITY_LOG

# Check critical file permissions
CRITICAL_FILES="/etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config"
for file in \$CRITICAL_FILES; do
    if [ -f "\$file" ]; then
        PERMS=\$(stat -c "%a" "\$file")
        echo "[\$DATE] \$file: \$PERMS" >> \$INTEGRITY_LOG
    fi
done

# Check for new SUID files
find / -type f -perm -4000 -exec ls -la {} \; 2>/dev/null | sort > /tmp/suid_check.tmp
if [ -f /var/log/suid_baseline ]; then
    if ! diff /var/log/suid_baseline /tmp/suid_check.tmp >/dev/null; then
        echo "[\$DATE] WARNING: SUID files changed!" >> \$INTEGRITY_LOG
    fi
else
    cp /tmp/suid_check.tmp /var/log/suid_baseline
fi

# Check network connections
CONNECTIONS=\$(netstat -tn | grep ESTABLISHED | wc -l)
echo "[\$DATE] Active connections: \$CONNECTIONS" >> \$INTEGRITY_LOG

echo "[\$DATE] Integrity check completed." >> \$INTEGRITY_LOG
EOF

chmod +x /usr/local/bin/integrity-check

# ========================================================
# APPLY CONFIGURATION FILES
# ========================================================
print_section "Applying hardened configuration files..."
apply_config "etc-aide-conf" "/etc/aide.conf"
apply_config "etc-bash-bashrc" "/etc/bash.bashrc"
apply_config "etc-crypttab" "/etc/crypttab"
apply_config "etc-default-passwd" "/etc/default/passwd"
apply_config "etc-dhclient-conf" "/etc/dhclient.conf"
apply_config "etc-hardening-wrapper-conf" "/etc/hardening-wrapper.conf"
apply_config "etc-iptables-ip6tables.rules" "/etc/iptables/ip6tables.rules"
apply_config "etc-iptables-iptables.rules" "/etc/iptables/iptables.rules"
apply_config "etc-locale-conf" "/etc/locale.conf"
apply_config "etc-locale-gen" "/etc/locale.gen"
apply_config "etc-modprobe-d-blacklist-firewire" "/etc/modprobe.d/blacklist-firewire"

# ========================================================
# CREATE COMPREHENSIVE BACKUP
# ========================================================
print_section "Creating comprehensive security backup..."
BACKUP_DIR="/root/security_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -p /etc/ssh/sshd_config "$BACKUP_DIR/" 2>/dev/null
cp -p /etc/sysctl.conf.backup "$BACKUP_DIR/" 2>/dev/null
cp -p /etc/security/limits.conf "$BACKUP_DIR/" 2>/dev/null
iptables-save > "$BACKUP_DIR/iptables_backup"
ufw status verbose > "$BACKUP_DIR/ufw_backup"

# ========================================================
# FINAL OPTIMIZATIONS AND CLEANUP
# ========================================================
print_section "Applying final optimizations..."

# Optimize log rotation for performance
cat > /etc/logrotate.d/security-logs << EOF
/var/log/auth.log /var/log/syslog /var/log/integrity-check.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF

# Set up automatic integrity checking
echo "0 2 * * * root /usr/local/bin/integrity-check" > /etc/cron.d/integrity-check
echo "0 6 * * * root /usr/local/bin/security-performance-check >> /var/log/security-performance.log" > /etc/cron.d/security-performance

# Apply final sysctl optimizations
sysctl -p

# Create quick status script
cat > /usr/local/bin/security-status << EOF
#!/bin/bash
echo "=== Security Status ==="
echo "Firewall: \$(ufw status | head -1)"
echo "SSH attempts blocked: \$(iptables -L | grep -c DROP || echo 0)"
echo "Active connections: \$(netstat -tn | grep ESTABLISHED | wc -l)"
echo "System load: \$(uptime | awk -F'load average:' '{print \$2}')"
echo "Memory usage: \$(free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}')"
EOF
chmod +x /usr/local/bin/security-status

# ========================================================
# COMPLETION MESSAGE
# ========================================================
print_section "Enhanced Performance-Aware Hardening Completed!"
echo "=================================================================="
echo "System hardening completed successfully at $(date)"
echo ""
echo "Performance optimizations applied:"
echo "- Connection limit: $CONN_LIMIT"
echo "- Rate limit: $RATE_LIMIT"
echo "- Burst limit: $BURST_LIMIT"
echo "- Log limit: $LOG_LIMIT"
echo ""
echo "Monitoring tools installed:"
echo "- /usr/local/bin/security-status (quick status)"
echo "- /usr/local/bin/security-performance-check (detailed report)"
echo "- /usr/local/bin/integrity-check (system integrity)"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Run 'security-status' to check current security status"
echo "=================================================================="

exit 0
'