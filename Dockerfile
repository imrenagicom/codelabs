FROM nginx:alpine

# Copy static assets into nginx
COPY . /usr/share/nginx/html

# Cloud Run by default uses port 8080
RUN sed -i 's/listen  *80;/listen 8080;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8080
