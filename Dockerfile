FROM nginx:alpine
COPY src/ /usr/share/nginx/html
#COPY cfg/ /etc/nginx/conf.d
COPY cfg/nginx.conf /etc/nginx/nginx.conf

