FROM nginx:alpine
COPY src/ /usr/share/nginx/html
COPY cfg/ /etc/nginx/conf.d

