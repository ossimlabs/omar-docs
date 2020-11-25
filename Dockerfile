FROM httpd:2.4
COPY site /usr/local/apache2/htdocs/

FROM sonarqube:2.8
COPY sonar.properties /opt/sonarqube/conf/