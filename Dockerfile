FROM php:7.0-fpm
MAINTAINER Javier Jerónimo <jcjeronimo@genexies.net>
#
# @param[in] ENVIRONMENT        Configuration environment to use.
#
# @param[in] REPOSITORIES       Git repositories to clone (each: https including
#                               credentials in URL)

ENV ENVIRONMENT=
ENV REPOSITORIES=

# Required to install libapache2-mod-fastcgi
RUN echo "deb http://http.us.debian.org/debian jessie main non-free" >> /etc/apt/sources.list

RUN apt-get update

# Install Supervisor
RUN apt-get install -y supervisor
ADD etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Git
RUN apt-get install -y git

# Install wget
RUN apt-get install -y wget

# Install php-pear
RUN apt-get install -y php-pear

# Install sudo
RUN apt-get install -y sudo

# Install OPcache
RUN docker-php-ext-install opcache mysqli
ADD opcache.ini /opcache.ini
RUN cat /opcache.ini >> /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini

# Install Apache
RUN apt-get install -y apache2
ADD etc/apache2/apache2.conf /etc/apache2/apache2.conf

# Install FastCGI process
RUN apt-get install -y php5-fpm
ADD usr/local/etc/php-fpm.conf /usr/local/etc/php-fpm.conf

# Apache's MPM module: Event
RUN apt-get -y install apache2-mpm-event
RUN a2enmod mpm_event

# Apache's module to communicate with FastCGI process: fastcgi
RUN apt-get install -y libapache2-mod-fastcgi
ADD etc/apache2/conf-available/fastcgi.conf /etc/apache2/conf-available/fastcgi.conf
RUN a2enconf fastcgi

# Enable Apache modules
RUN a2enmod rewrite actions

# Remove index.html in /var/www/html
RUN rm -r /var/www/html/*

# Auxiliary functions for entry-point
ADD auxiliary-functions.sh /auxiliary-functions.sh

# Our entry-point that fallback to parent's
ADD entrypoint.sh /entrypoint.sh
RUN chmod u+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Same default parameter to parent's entry-point
CMD ["/usr/bin/supervisord"]
