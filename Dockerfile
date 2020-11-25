FROM httpd:2.4
COPY site /usr/local/apache2/htdocs/

FROM sonarqube:8.2-community
#COPY sonar.properties /opt/sonarqube/conf/