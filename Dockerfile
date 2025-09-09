# Menggunakan base image Ubuntu 22.04
FROM ubuntu:22.04

# PERUBAHAN: Menggunakan ENV agar variabel tersedia saat runtime, bukan hanya saat build
ARG NGROK_TOKEN=""
ARG REGION="ap"
ARG USERNAME=""
ARG USER_PASSWORD=""
ENV DEBIAN_FRONTEND=noninteractive

# Instalasi paket-paket minimal yang dibutuhkan untuk SSH
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    wget curl \
    openssh-server \
    ca-certificates \
    adduser \
    sudo \
    jq

# Instalasi ngrok
RUN curl -L https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /ngrok.tgz && \
    tar xvzf /ngrok.tgz -C /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm /ngrok.tgz

# Membuat user non-root untuk koneksi SSH
# PERUBAHAN: Menggunakan ENV untuk mengambil nilai
RUN useradd -m -s /bin/bash ${USERNAME} && \
    adduser "${USERNAME}" sudo && \
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd && \
    adduser ${USERNAME} sudo

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# --- Skrip Startup Kontainer yang Diperbaiki ---
RUN echo "#!/bin/bash" > /startup.sh && \
    # PERBAIKAN: Konfigurasi authtoken ngrok terlebih dahulu
    echo "echo '>>> Mengkonfigurasi Ngrok Authtoken...'" >> /startup.sh && \
    echo "/usr/local/bin/ngrok config add-authtoken \$NGROK_TOKEN" >> /startup.sh && \
    # Menjalankan server SSH di background
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    # PERBAIKAN: Menjalankan tunnel ngrok dengan sintaks v3 yang benar
    echo "/usr/local/bin/ngrok tcp --region \$REGION 22 &" >> /startup.sh && \
    # Beri waktu agar tunnel ngrok sempat terbentuk
    echo "sleep 5" >> /startup.sh && \
    # Menampilkan informasi login SSH
    echo "echo '--- SSH Access Info ---'" >> /startup.sh && \
    echo "URL=\$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')" >> /startup.sh && \
    echo "HOSTNAME=\$(echo \$URL | sed -e 's/tcp:\\/\\///' -e 's/:.*//')" >> /startup.sh && \
    echo "PORT=\$(echo \$URL | sed -e 's/.*://')" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo '>>> Jalankan perintah ini di Termux Anda:'" >> /startup.sh && \
    echo "echo \"ssh \${USERNAME}@\${HOSTNAME} -p \${PORT}\"" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo \"Password: \${USER_PASSWORD}\"" >> /startup.sh && \
    # Menjaga agar kontainer tetap berjalan
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

# Persiapan akhir untuk SSHD
RUN mkdir -p /run/sshd

# Mengekspos port 22
EXPOSE 22

# Menjalankan skrip startup
CMD ["/bin/bash", "/startup.sh"]
