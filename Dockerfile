# Menggunakan base image Ubuntu 22.04
FROM ubuntu:22.04

# Variabel ini akan diambil dari dashboard Railway saat runtime
ENV NGROK_TOKEN=""
ENV REGION="ap"
ENV USERNAME="user"
ENV USER_PASSWORD="password"
ENV DEBIAN_FRONTEND=noninteractive

# Instalasi paket-paket yang dibutuhkan
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    wget curl \
    openssh-server \
    ca-certificates \
    sudo \
    jq

# Instalasi ngrok
RUN curl -L https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /ngrok.tgz && \
    tar xvzf /ngrok.tgz -C /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm /ngrok.tgz

# --- DIHAPUS DARI SINI ---
# Perintah useradd dihapus dari build time.
# Ini akan kita pindahkan ke startup.sh agar menggunakan variabel dari Railway.

# --- KONFIGURASI SERVER SSH ---
# Tetap di sini karena ini adalah konfigurasi file statis
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    mkdir -p /run/sshd

# --- Skrip Startup Kontainer yang Disempurnakan untuk Railway ---
RUN echo "#!/bin/bash" > /startup.sh && \
    # --- BLOK PEMBUATAN USER SAAT RUNTIME ---
    echo "echo '>>> Memeriksa dan membuat user...'" >> /startup.sh && \
    # Cek apakah user sudah ada atau belum (untuk mencegah error saat restart)
    echo "if ! id -u \"\$USERNAME\" >/dev/null 2>&1; then" >> /startup.sh && \
    echo "  echo \"User '\$USERNAME' tidak ditemukan. Membuat user baru...\"" >> /startup.sh && \
    echo "  useradd -m -s /bin/bash \"\$USERNAME\"" >> /startup.sh && \
    echo "  echo \"\${USERNAME}:\${USER_PASSWORD}\" | chpasswd" >> /startup.sh && \
    echo "  adduser \"\$USERNAME\" sudo" >> /startup.sh && \
    echo "  echo \"User '\$USERNAME' berhasil dibuat.\"" >> /startup.sh && \
    echo "fi" >> /startup.sh && \
    # --- AKHIR BLOK PEMBUATAN USER ---
    echo "" >> /startup.sh && \
    echo "echo '>>> Mengkonfigurasi Ngrok Authtoken...'" >> /startup.sh && \
    echo "/usr/local/bin/ngrok config add-authtoken \$NGROK_TOKEN" >> /startup.sh && \
    echo "echo '>>> Menjalankan server SSH dan tunnel Ngrok...'" >> /startup.sh && \
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    echo "/usr/local/bin/ngrok tcp --region \$REGION 22 &" >> /startup.sh && \
    echo "sleep 5" >> /startup.sh && \
    echo "echo '--- SSH Access Info ---'" >> /startup.sh && \
    echo "URL=\$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')" >> /startup.sh && \
    echo "HOSTNAME=\$(echo \$URL | sed -e 's/tcp:\\/\\///' -e 's/:.*//')" >> /startup.sh && \
    echo "PORT=\$(echo \$URL | sed -e 's/.*://')" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo '>>> Jalankan perintah ini di Termux Anda:'" >> /startup.sh && \
    echo "echo \"ssh \${USERNAME}@\${HOSTNAME} -p \${PORT}\"" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo \"Password: \${USER_PASSWORD}\"" >> /startup.sh && \
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

EXPOSE 22
CMD ["/bin/bash", "/startup.sh"]
