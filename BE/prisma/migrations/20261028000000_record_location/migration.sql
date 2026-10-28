ALTER TABLE "chat_rooms" ADD COLUMN "place_name" VARCHAR(100), ADD COLUMN "latitude" DOUBLE PRECISION, ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "chat_rooms" ADD CONSTRAINT "chat_rooms_location_check" CHECK (
(place_name IS NULL AND latitude IS NULL AND longitude IS NULL) OR
(place_name IS NOT NULL AND length(trim(place_name)) > 0 AND latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180));
