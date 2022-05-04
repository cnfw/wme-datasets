# Download Source townland data
FROM alpine as townland-data

WORKDIR /workdir
RUN apk --update add openssl wget

RUN wget -O generalised_100m.geojson http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_0.geojson
RUN wget -O generalised_50m.geojson  http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_1.geojson
RUN wget -O generalised_20m.geojson  http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_2.geojson
RUN wget -O ungeneralised.geojson    http://data-osi.opendata.arcgis.com/datasets/1c895c5fa0bb471292891c0998e25906_3.geojson

## Build Townland files
FROM node:8 as townland_file_builder

WORKDIR /workdir

COPY --from=townland-data * ./

COPY townland-clipper/ ./

RUN npm install

RUN mkdir generalised_100m generalised_50m generalised_20m ungeneralised

RUN node . --output=generalised_100m --input=generalised_100m.geojson
RUN node . --reduce --output=generalised_100m --input=generalised_100m.geojson

RUN node . --output=generalised_50m --input=generalised_50m.geojson
RUN node . --reduce --output=generalised_50m --input=generalised_50m.geojson

RUN node . --output=generalised_20m --input=generalised_20m.geojson
RUN node . --reduce --output=generalised_20m --input=generalised_20m.geojson

RUN node --max-old-space-size=4096 . --output=ungeneralised --input=ungeneralised.geojson
RUN node --max-old-space-size=4096 . --reduce --output=ungeneralised --input=ungeneralised.geojson


# Build CSS
FROM node:8 AS css_builder

WORKDIR /workdir

COPY assets/ _gulp/ ./
COPY package*.json ./
COPY gulpfile.js ./

RUN npm install
RUN npm install --only=dev
RUN node_modules/.bin/gulp css && node_modules/.bin/gulp icons


# Build Jekyll Site
FROM ruby:2.3.0 as jekyll

WORKDIR /workdir

COPY Gemfile* ./

RUN bundle install

COPY --from=css_builder /workdir ./
COPY . ./

RUN bash generate_county_collection.sh
RUN jekyll build

# Nginx server
FROM nginx

EXPOSE 80

WORKDIR /usr/share/nginx/html

COPY --from=townland_file_builder /workdir/generalised_100m ./generalised_100m/
COPY --from=townland_file_builder /workdir/generalised_50m ./generalised_50m/
COPY --from=townland_file_builder /workdir/generalised_20m ./generalised_20m/
COPY --from=townland_file_builder /workdir/ungeneralised ./ungeneralised/

COPY nginx-default.conf /etc/nginx/conf.d/default.conf
COPY --from=jekyll /workdir/_site ./
