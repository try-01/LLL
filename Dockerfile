# Menggunakan base image Ubuntu 22.04
FROM ubuntu:22.04

# Argumen yang dibutuhkan saat build
ARG NGROK_TOKEN
ARG REGION=ap
ARG USERNAME
ARG USER_PASSWORD

# Mengatur environment agar tidak ada prompt interaktif saat instalasi
ENV DEBIAN_FRONTEND=noninteractive

# Instalasi paket-paket minimal yang dibutuhkan untuk SSH
# Kita hapus XFCE, VNC, dan dependensi grafis lainnya
RUN apt update && apt upgrade -y && \
    apt install -y --no-install-recommends \
    wget curl \
    openssh-server \
    sudo \
    ca-certificates \
    jq  # jq adalah utilitas JSON yang ringan untuk mengambil URL ngrok

# Instalasi ngrok
RUN curl -L https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -o /ngrok.tgz && \
    tar xvzf /ngrok.tgz -C /usr/local/bin && \
    chmod +x /usr/local/bin/ngrok && \
    rm /ngrok.tgz

# Membuat user non-root untuk koneksi SSH
RUN useradd -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd && \
    adduser ${USERNAME} sudo

# --- Skrip Startup Kontainer yang Disederhanakan ---
RUN echo "#!/bin/bash" > /startup.sh && \
    # Menjalankan server SSH di background
    echo "/usr/sbin/sshd -D &" >> /startup.sh && \
    # Menjalankan tunnel ngrok untuk port SSH (22) di background
    echo "/usr/local/bin/ngrok tcp --region \$REGION --authtoken \$NGROK_TOKEN 22 &" >> /startup.sh && \
    # Beri waktu 5 detik agar tunnel ngrok sempat terbentuk
    echo "sleep 5" >> /startup.sh && \
    # Menampilkan informasi login SSH yang mudah disalin
    echo "echo '--- SSH Access Info ---'" >> /startup.sh && \
    echo "URL=\$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')" >> /startup.sh && \
    echo "HOSTNAME=\$(echo \$URL | sed -e 's/tcp:\\/\\///' -e 's/:.*//')" >> /startup.sh && \
    echo "PORT=\$(echo \$URL | sed -e 's/.*://')" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo '>>> Jalankan perintah ini di Termux Anda:'" >> /startup.sh && \
    echo "echo \"ssh ${USERNAME}@\${HOSTNAME} -p \${PORT}\"" >> /startup.sh && \
    echo "echo" >> /startup.sh && \
    echo "echo \"Password: ${USER_PASSWORD}\"" >> /startup.sh && \
    # Perintah ini menjaga agar kontainer tetap berjalan selamanya
    echo "tail -f /dev/null" >> /startup.sh && \
    chmod +x /startup.sh

# Persiapan akhir untuk SSHD agar bisa berjalan di dalam Docker
RUN mkdir -p /run/sshd

# Mengekspos port 22 (opsional, tapi praktik yang baik)
EXPOSE 22

# Menjalankan skrip startup saat kontainer dimulai
CMD ["/bin/bash", "/startup.sh"]
