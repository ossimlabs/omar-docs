FROM httpd:2.4
COPY site /usr/local/apache2/htdocs/

docker import https://sonarqube.ossim.io/
