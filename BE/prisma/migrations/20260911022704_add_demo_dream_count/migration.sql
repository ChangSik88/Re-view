-- CreateTable
CREATE TABLE "demo_dream_counts" (
    "demo_count_id" BIGSERIAL NOT NULL,
    "date" DATE NOT NULL,
    "category" VARCHAR(20) NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "PK_DEMO_DREAM_COUNTS" PRIMARY KEY ("demo_count_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "UQ_DEMO_COUNT_DATE_CATEGORY" ON "demo_dream_counts"("date", "category");
