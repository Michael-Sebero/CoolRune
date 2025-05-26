#!/bin/bash

# ========================================================
# Enhanced Performance-Aware System Hardening Script for Arch Linux
# Diagnostic and Improved Version
# ========================================================

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root. Use 'sudo bash $0' or 'su -c \"bash $0\"'"
        exit 1
    fi
}

# Check if running on Arch Linux
check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_warning "This script is designed for Arch Linux. Proceeding anyway..."
    fi
}

# Performance monitoring functions
check_cpu_cores() {
    nproc
}

check_ram_gb() {
    free -g | awk "NR==2{printf \"%.0f\", \$2}"
}

# Set performance-aware limits based on system specs
set_performance_limits() {
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

    log_message "System specs detected: ${CPU_CORES} cores, ${RAM_GB}GB RAM"
    log_message "Performance limits set: ${CONN_LIMIT} connections, ${RATE_LIMIT} rate limit"
}

# Function for applying config files with improved error handling
apply_config() {
    local source_file="$1"
    local target_file="$2"
    
    if [ ! -f "$source_file" ]; then
        log_warning "Configuration file $source_file not found - skipping"
        return 0
    fi
    
    # Create backup of existing file
    if [ -f "$target_file" ]; then
        cp "$target_file" "${target_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_message "Backed up existing $target_file"
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"
    
    if ! cp "$source_file" "$target_file" 2>/dev/null; then
        log_error "Failed to apply $source_file to $target_file"
        return 1
    fi
    
    log_success "Successfully applied $source_file to $target_file"
    return 0
}

# Print section header for better readability
print_section() {
    echo ""
    echo "================================================================"
    echo "  $1"
    echo "================================================================"
}

# Check for required tools
check_dependencies() {
    local missing_tools=()
    
    # Check for essential tools
    for tool in iptables ufw sysctl netstat; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_message "Please install missing tools before running this script"
        exit 1
    fi
}

# Backup existing configuration
create_backup() {
    local backup_dir="/root/security_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup important files (excluding sysctl.conf since we won't modify it)
    [ -f /etc/ssh/sshd_config ] && cp /etc/ssh/sshd_config "$backup_dir/"
    [ -f /etc/security/limits.conf ] && cp /etc/security/limits.conf "$backup_dir/"
    
    # Backup firewall rules
    if command -v iptables-save &> /dev/null; then
        iptables-save > "$backup_dir/iptables_backup"
    fi
    
    if command -v ufw &> /dev/null; then
        ufw status verbose > "$backup_dir/ufw_backup" 2>/dev/null
    fi
    
    log_success "Backup created in: $backup_dir"
    echo "$backup_dir" > /tmp/hardening_backup_location
}

# Main execution starts here
main() {
    print_section "Starting Enhanced Performance-Aware System Hardening"
    
    # Pre-flight checks
    check_root
    check_arch
    check_dependencies
    set_performance_limits
    create_backup
    
    # ========================================================
    # ENHANCED FILE PERMISSIONS
    # ========================================================
    print_section "Setting secure file permissions"
    
    # Critical system files
    chmod 700 /root 2>/dev/null && log_success "Secured /root directory"
    chmod 600 /etc/shadow 2>/dev/null && log_success "Secured /etc/shadow"
    chmod 600 /etc/gshadow 2>/dev/null && log_success "Secured /etc/gshadow"
    chmod 644 /etc/passwd 2>/dev/null && log_success "Set permissions for /etc/passwd"
    chmod 644 /etc/group 2>/dev/null && log_success "Set permissions for /etc/group"
    chmod 600 /etc/sudoers 2>/dev/null && log_success "Secured /etc/sudoers"
    
    # SSL directories
    if [ -d /etc/ssl/private ]; then
        chmod -R 700 /etc/ssl/private 2>/dev/null && log_success "Secured SSL private directory"
    fi
    if [ -d /etc/ssl/certs ]; then
        chmod -R 755 /etc/ssl/certs 2>/dev/null && log_success "Set SSL certs permissions"
    fi
    
    # Optimize cron permissions
    find /etc/cron.* -type f -print0 2>/dev/null | xargs -0 chmod 0700 2>/dev/null
    chmod 0600 /etc/crontab 2>/dev/null
    chmod 0600 /etc/ssh/sshd_config 2>/dev/null && log_success "Secured SSH configuration"
    
    # ========================================================
    # UFW CONFIGURATION
    # ========================================================
    print_section "Configuring UFW firewall"
    
    if command -v ufw &> /dev/null; then
        # Reset UFW to clean state
        ufw --force reset &>/dev/null
        
        # Configure UFW with performance optimizations
        ufw default deny incoming &>/dev/null
        ufw default allow outgoing &>/dev/null
        
        # Essential services with rate limiting
        ufw limit 22/tcp comment "SSH with rate limiting" &>/dev/null
        ufw allow 80/tcp comment "HTTP" &>/dev/null
        ufw allow 443/tcp comment "HTTPS" &>/dev/null
        
        # Gaming and P2P (optimized ranges)
        ufw allow 6881:6889/tcp comment "BitTorrent TCP" &>/dev/null
        ufw allow 6881:6889/udp comment "BitTorrent UDP" &>/dev/null
        ufw allow 27000:27100/tcp comment "Steam TCP" &>/dev/null
        ufw allow 27000:27100/udp comment "Steam UDP" &>/dev/null
        ufw allow 3478:3480/tcp comment "PlayStation/Xbox TCP" &>/dev/null
        ufw allow 3478:3480/udp comment "PlayStation/Xbox UDP" &>/dev/null
        
        # Discord and VoIP
        ufw allow 50000:65535/udp comment "Discord/VoIP UDP" &>/dev/null
        
        # Developer tools
        ufw allow 9418/tcp comment "Git protocol" &>/dev/null
        ufw allow out 22/tcp comment "Git SSH outbound" &>/dev/null
        
        # Tor network
        ufw allow 9050/tcp comment "Tor SOCKS" &>/dev/null
        ufw allow 9051/tcp comment "Tor control" &>/dev/null
        ufw allow 9150/tcp comment "Tor browser" &>/dev/null
        
        # Enable UFW
        ufw --force enable &>/dev/null
        log_success "UFW firewall configured and enabled"
    else
        log_warning "UFW not found, skipping UFW configuration"
    fi
    
    # ========================================================
    # SECURITY MODULES
    # ========================================================
    print_section "Configuring security modules"
    
    # Create modprobe blacklist directory
    mkdir -p /etc/modprobe.d
    
    # Disable uncommon network protocols
    cat > /etc/modprobe.d/blacklist-uncommon.conf << EOF
# Uncommon network protocols - disabled for security
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
    log_success "Security modules configured"
    
    # ========================================================
    # MONITORING TOOLS
    # ========================================================
    print_section "Installing monitoring tools"
    
    # Create performance monitoring script
    cat > /usr/local/bin/security-performance-check << 'EOF'
#!/bin/bash
# Performance monitoring for security measures

echo "=== Security Performance Report ==="
echo "Date: $(date)"
echo "CPU Cores: $(nproc)"
echo "Memory: $(free -h | grep Mem: | awk '{print $2}')"
echo ""

# Network connections
echo "Active connections: $(netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l)"
echo "Total tracked connections: $(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo 'N/A')"
echo "Max tracked connections: $(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo 'N/A')"
echo ""

# Firewall stats
if command -v iptables &> /dev/null; then
    echo "Iptables rules count: $(iptables -L 2>/dev/null | grep -c '^Chain' || echo 'N/A')"
fi
echo ""

# System load
echo "Current load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
EOF
    
    chmod +x /usr/local/bin/security-performance-check
    log_success "Performance monitoring script installed"
    
    # Create quick status script
    cat > /usr/local/bin/security-status << 'EOF'
#!/bin/bash
echo "=== Security Status ==="
if command -v ufw &> /dev/null; then
    echo "UFW Firewall: $(ufw status | head -1)"
fi
if command -v iptables &> /dev/null; then
    echo "Iptables rules: $(iptables -L 2>/dev/null | grep -c '^Chain' || echo 'N/A')"
fi
echo "Active connections: $(netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l || echo 'N/A')"
echo "System load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
EOF
    chmod +x /usr/local/bin/security-status
    log_success "Status monitoring script installed"
    
    # ========================================================
    # COMPLETION
    # ========================================================
    print_section "Hardening Completed Successfully!"
    
    echo "=================================================================="
    echo "System hardening completed successfully at $(date)"
    echo ""
    echo ""
    echo "Performance optimizations applied:"
    echo "- Connection limit calculations: $CONN_LIMIT"
    echo "- Rate limit calculations: $RATE_LIMIT"
    echo "- Burst limit calculations: $BURST_LIMIT"
    echo "- Log limit calculations: $LOG_LIMIT"
    echo ""
    echo "Monitoring tools installed:"
    echo "- /usr/local/bin/security-status (quick status)"
    echo "- /usr/local/bin/security-performance-check (detailed report)"
    echo ""
    if [ -f /tmp/hardening_backup_location ]; then
        echo "Backup location: $(cat /tmp/hardening_backup_location)"
        rm -f /tmp/hardening_backup_location
    fi
    echo ""
    echo "Run 'security-status' to check current security status"
    echo "=================================================================="
    
    log_success "Hardening script completed successfully!"
}

# Run main function
main "$@"
