# Download Source townland data
FROM alpine as townland-data

WORKDIR /workdir
RUN apk --update add openssl wget

RUN wget -O generalised_100m.geojson http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_0.geojson
RUN wget -O generalised_50m.geojson  http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_1.geojson
RUN wget -O generalised_20m.geojson  http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_2.geojson
RUN wget -O ungeneralised.geojson    http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_3.geojson

## Build Townland files
FROM python:3 as python

WORKDIR /workdir

COPY --from=townland-data * ./

RUN pip3 install ijson simplejson

COPY townland-clipper/townland-clipper.py ./

RUN mkdir generalised_100m && python3 townland-clipper.py --all --output generalised_100m generalised_100m.geojson
RUN python3 townland-clipper.py --all --reduce --output generalised_100m generalised_100m.geojson

RUN mkdir generalised_50m && python3 townland-clipper.py --all --output generalised_50m generalised_50m.geojson
RUN python3 townland-clipper.py --all --reduce --output generalised_50m generalised_50m.geojson

RUN mkdir generalised_20m && python3 townland-clipper.py --all --output generalised_20m generalised_20m.geojson
RUN python3 townland-clipper.py --all --reduce --output generalised_20m generalised_20m.geojson

RUN mkdir ungeneralised && python3 townland-clipper.py --all --output ungeneralised ungeneralised.geojson
RUN python3 townland-clipper.py --all --reduce --output ungeneralised ungeneralised.geojson


# Build CSS
FROM node:8 AS node

WORKDIR /workdir

COPY assets/ _gulp/ ./
COPY package*.json ./
COPY gulpfile.js ./

RUN npm install
RUN npm install --only=dev
RUN node_modules/.bin/gulp css && node_modules/.bin/gulp icons


# Build Jekyll Site
FROM ruby as jekyll

WORKDIR /workdir

COPY Gemfile* ./

RUN bundle install

COPY --from=node /workdir ./
COPY . ./

RUN bash generate_county_collection.sh
RUN jekyll build

# Nginx server
FROM nginx

EXPOSE 80

WORKDIR /usr/share/nginx/html

COPY --from=python /workdir/generalised_100m /workdir/generalised_50m /workdir/generalised_20m /workdir/ungeneralised ./
COPY nginx-default.conf /etc/nginx/conf.d/default.conf
COPY --from=jekyll /workdir/_site ./
