-- AlterTable
ALTER TABLE "chat_rooms" ADD COLUMN     "latitude" DOUBLE PRECISION,
ADD COLUMN     "longitude" DOUBLE PRECISION,
ADD COLUMN     "place_name" VARCHAR(100);
