FROM kalilinux/kali-rolling

# ── System update ─────────────────────────────────────────────────────────────
RUN apt-get update && apt-get upgrade -y

# ── Core Linux utilities ────────────────────────────────────────────────────
RUN apt-get install -y \
        # Shell & text
        bash \
        zsh \
        vim \
        nano \
        less \
        man-db \
        tree \
        htop \
        # File & archive
        file \
        zip \
        unzip \
        tar \
        gzip \
        bzip2 \
        7zip \
        # Process & system
        procps \
        lsof \
        util-linux \
        psmisc \
        # Network — basic
        iputils-ping \
        iputils-tracepath \
        iproute2 \
        net-tools \
        traceroute \
        bind9-dnsutils \
        whois \
        arp-scan \
        # Data & encoding
        xxd \
        bsdmainutils \
        openssl \
        # Build tools
        gcc \
        g++ \
        make \
        perl \
        ruby \
        python3 \
        python3-pip \
        git \
        binutils \
        strace \
        ltrace \
        gdb \
    && rm -rf /var/lib/apt/lists/*

# ── Cybersecurity tools ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y \
        # Packet analysis
        tcpdump \
        tshark \
        wireshark \
        # Scanning & enumeration
        nmap \
        gobuster \
        dirb \
        nikto \
        ffuf \
        # SMB / AD enumeration
        smbclient \
        enum4linux \
        ldap-utils \
        # Password attacks
        hydra \
        medusa \
        john \
        hashcat \
        # Exploitation
        netcat-traditional \
        socat \
        # Web & SQL
        sqlmap \
        curl \
        wget \
        # Protocols
        telnet \
        ftp \
        openssh-client \
        sshpass \
        # Pivoting
        proxychains4 \
        # Exploit search
        exploitdb \
        # Post-exploitation
        sudo \
        cron \
        # Python security libs
        python3-pwntools \
        python3-impacket \
        # Wordlists
        wordlists \
    && rm -rf /var/lib/apt/lists/* \
    && gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true

# ── Fix Kali bug #9085 (nmap unusable in Docker) ──────────────────────────────
# Kali's nmap package sets file capabilities on its binary during install:
#   setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/lib/nmap/nmap
# cap_net_admin is NOT in Docker's default capability set, and a process can
# never execute a binary whose file capabilities exceed its own capability
# bounding set — so nmap fails to run at all ("Operation not permitted",
# exit 126) in a stock Docker container, including during this very build.
# Fix (per Kali's own maintainer, https://bugs.kali.org/view.php?id=9085):
# re-apply setcap without cap_net_admin. cap_net_raw alone is enough for raw
# packet scans and IS in Docker's default bounding set.
RUN apt-get update && apt-get install -y --no-install-recommends libcap2-bin \
    && setcap cap_net_raw,cap_net_bind_service+eip /usr/lib/nmap/nmap \
    && rm -rf /var/lib/apt/lists/*

# ── MySQL client (service enumeration lab) ────────────────────────────────────
RUN apt-get update && apt-get install -y default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# ── CPU OpenCL runtime for hashcat (no GPU available inside containers) ───────
# --no-install-recommends is essential here: pocl-opencl-icd's recommends chain
# pulls in an entire unrelated desktop/AI stack (Qt6, onnxruntime, pipewire,
# wacom libs...) that isn't needed and bloats/slows the build enormously.
RUN apt-get update && apt-get install -y --no-install-recommends pocl-opencl-icd \
    && rm -rf /var/lib/apt/lists/*

# ── Verify key commands are available ─────────────────────────────────────────
RUN ping -c1 127.0.0.1 > /dev/null 2>&1 && echo "ping OK" && \
    ip addr show lo > /dev/null 2>&1    && echo "ip OK"   && \
    ifconfig lo > /dev/null 2>&1        && echo "ifconfig OK" && \
    nmap -V > /dev/null 2>&1            && echo "nmap OK"

# ── Create hacker user with sudo ──────────────────────────────────────────────
RUN useradd -m -s /bin/bash hacker && \
    echo 'hacker:hacker' | chpasswd && \
    echo 'hacker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    usermod -aG sudo hacker

USER hacker
WORKDIR /home/hacker
CMD ["/bin/bash"]
