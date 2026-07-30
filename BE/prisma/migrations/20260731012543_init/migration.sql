-- pgvector 확장: chat_rooms.content_vector 컬럼(Unsupported("vector"))이 사용
CREATE EXTENSION IF NOT EXISTS vector;

-- CreateTable
CREATE TABLE "auth_tokens" (
    "auth_token_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "refresh_token" VARCHAR(512) NOT NULL,
    "device_id" BIGINT,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_AUTH_TOKENS" PRIMARY KEY ("auth_token_id")
);

-- CreateTable
CREATE TABLE "categories" (
    "category_id" BIGSERIAL NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_CATEGORIES" PRIMARY KEY ("category_id")
);

-- CreateTable
CREATE TABLE "chat_images" (
    "chat_image_id" BIGSERIAL NOT NULL,
    "room_id" BIGINT NOT NULL,
    "image_url" VARCHAR(2048) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_CHAT_IMAGES" PRIMARY KEY ("chat_image_id")
);

-- CreateTable
CREATE TABLE "chat_messages" (
    "message_id" BIGSERIAL NOT NULL,
    "room_id" BIGINT NOT NULL,
    "role" VARCHAR(10) NOT NULL,
    "content" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_CHAT_MESSAGES" PRIMARY KEY ("message_id")
);

-- CreateTable
CREATE TABLE "chat_rooms" (
    "room_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "title" VARCHAR(50),
    "content" TEXT,
    "tags" VARCHAR(50),
    "is_marked" BOOLEAN NOT NULL DEFAULT false,
    "routine_type" VARCHAR(20),
    "content_vector" vector(3072), -- gemini-embedding-001 기본 출력 차원(실측 확인)
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_CHAT_ROOMS" PRIMARY KEY ("room_id")
);

-- CreateTable
CREATE TABLE "customer_inquiries" (
    "inquiry_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "category" VARCHAR(30),
    "title" VARCHAR(100) NOT NULL,
    "content" TEXT NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "answer" TEXT,
    "answered_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_CUSTOMER_INQUIRIES" PRIMARY KEY ("inquiry_id")
);

-- CreateTable
CREATE TABLE "diary_entries" (
    "diary_entry_id" BIGSERIAL NOT NULL,
    "purchase_id" BIGINT NOT NULL,
    "room_id" BIGINT,
    "selected_date" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_DIARY_ENTRIES" PRIMARY KEY ("diary_entry_id")
);

-- CreateTable
CREATE TABLE "items" (
    "item_id" BIGSERIAL NOT NULL,
    "category_id" BIGINT NOT NULL,
    "item_name" VARCHAR(50) NOT NULL,
    "headline" VARCHAR(50),
    "description" TEXT,
    "price" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_ITEMS" PRIMARY KEY ("item_id")
);

-- CreateTable
CREATE TABLE "item_images" (
    "item_image_id" BIGSERIAL NOT NULL,
    "item_id" BIGINT NOT NULL,
    "image_url" VARCHAR(2048) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_ITEM_IMAGES" PRIMARY KEY ("item_image_id")
);

-- CreateTable
CREATE TABLE "login_histories" (
    "login_history_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "device_id" BIGINT,
    "ip_address" VARCHAR(45),
    "is_success" BOOLEAN NOT NULL,
    "logged_in_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_LOGIN_HISTORIES" PRIMARY KEY ("login_history_id")
);

-- CreateTable
CREATE TABLE "notification_logs" (
    "notification_log_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "notification_type_id" BIGINT NOT NULL,
    "title" VARCHAR(100),
    "body" TEXT,
    "is_success" BOOLEAN NOT NULL,
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_NOTIFICATION_LOGS" PRIMARY KEY ("notification_log_id")
);

-- CreateTable
CREATE TABLE "notification_types" (
    "notification_type_id" BIGSERIAL NOT NULL,
    "code" VARCHAR(30) NOT NULL,
    "description" VARCHAR(100),

    CONSTRAINT "PK_NOTIFICATION_TYPES" PRIMARY KEY ("notification_type_id")
);

-- CreateTable
CREATE TABLE "payments" (
    "payment_id" BIGSERIAL NOT NULL,
    "purchase_id" BIGINT NOT NULL,
    "pg_provider" VARCHAR(30),
    "pg_transaction_id" VARCHAR(100),
    "payment_method" VARCHAR(20),
    "amount" INTEGER NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "paid_at" TIMESTAMPTZ(6),
    "refunded_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_PAYMENTS" PRIMARY KEY ("payment_id")
);

-- CreateTable
CREATE TABLE "purchases" (
    "purchase_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "item_id" BIGINT NOT NULL,
    "is_bought" BOOLEAN NOT NULL DEFAULT false,
    "bought_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_PURCHASES" PRIMARY KEY ("purchase_id")
);

-- CreateTable
CREATE TABLE "shipments" (
    "shipment_id" BIGSERIAL NOT NULL,
    "purchase_id" BIGINT NOT NULL,
    "address_id" BIGINT NOT NULL,
    "courier" VARCHAR(30),
    "tracking_number" VARCHAR(50),
    "status" VARCHAR(20) NOT NULL DEFAULT 'preparing',
    "shipped_at" TIMESTAMPTZ(6),
    "delivered_at" TIMESTAMPTZ(6),

    CONSTRAINT "PK_SHIPMENTS" PRIMARY KEY ("shipment_id")
);

-- CreateTable
CREATE TABLE "terms" (
    "term_id" BIGSERIAL NOT NULL,
    "term_type" VARCHAR(30) NOT NULL,
    "version" VARCHAR(20) NOT NULL,
    "title" VARCHAR(100) NOT NULL,
    "content_url" VARCHAR(2048),
    "is_required" BOOLEAN NOT NULL DEFAULT true,
    "effective_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_TERMS" PRIMARY KEY ("term_id")
);

-- CreateTable
CREATE TABLE "users" (
    "user_id" BIGSERIAL NOT NULL,
    "login_id" VARCHAR(50) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "birth" DATE,
    "gender" VARCHAR(10),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_USERS" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "user_addresses" (
    "address_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "recipient_name" VARCHAR(30) NOT NULL,
    "phone_number" VARCHAR(20) NOT NULL,
    "zipcode" VARCHAR(10),
    "address_line1" VARCHAR(200) NOT NULL,
    "address_line2" VARCHAR(200),
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_USER_ADDRESSES" PRIMARY KEY ("address_id")
);

-- CreateTable
CREATE TABLE "user_consents" (
    "consent_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "term_id" BIGINT NOT NULL,
    "is_agreed" BOOLEAN NOT NULL,
    "agreed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revoked_at" TIMESTAMPTZ(6),

    CONSTRAINT "PK_USER_CONSENTS" PRIMARY KEY ("consent_id")
);

-- CreateTable
CREATE TABLE "user_devices" (
    "device_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "push_token" VARCHAR(255),
    "device_type" VARCHAR(20) NOT NULL,
    "app_version" VARCHAR(20),
    "last_active_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_USER_DEVICES" PRIMARY KEY ("device_id")
);

-- CreateTable
CREATE TABLE "user_notification_settings" (
    "user_notification_setting_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "notification_type_id" BIGINT NOT NULL,
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_USER_NOTIFICATION_SETTINGS" PRIMARY KEY ("user_notification_setting_id")
);

-- CreateTable
CREATE TABLE "user_social_accounts" (
    "social_account_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "provider" VARCHAR(20) NOT NULL,
    "provider_user_id" VARCHAR(100) NOT NULL,
    "connected_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_USER_SOCIAL_ACCOUNTS" PRIMARY KEY ("social_account_id")
);

-- CreateTable
CREATE TABLE "user_withdrawals" (
    "withdrawal_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "reason" VARCHAR(200),
    "withdrawn_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "purge_scheduled_at" TIMESTAMPTZ(6),

    CONSTRAINT "PK_USER_WITHDRAWALS" PRIMARY KEY ("withdrawal_id")
);

-- CreateTable
CREATE TABLE "weekly_sessions" (
    "weekly_session_id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "weekly_content" TEXT,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PK_WEEKLY_SESSIONS" PRIMARY KEY ("weekly_session_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "UQ_NOTIFICATION_TYPES_CODE" ON "notification_types"("code");

-- CreateIndex
CREATE UNIQUE INDEX "UQ_USERS_LOGIN_ID" ON "users"("login_id");

-- CreateIndex
CREATE UNIQUE INDEX "UQ_USA_PROVIDER" ON "user_social_accounts"("provider", "provider_user_id");

-- AddForeignKey
ALTER TABLE "auth_tokens" ADD CONSTRAINT "FK_AUTH_TOKENS_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "auth_tokens" ADD CONSTRAINT "FK_AT_DEVICE" FOREIGN KEY ("device_id") REFERENCES "user_devices"("device_id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_images" ADD CONSTRAINT "FK_CI_ROOM" FOREIGN KEY ("room_id") REFERENCES "chat_rooms"("room_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "FK_CM_ROOM" FOREIGN KEY ("room_id") REFERENCES "chat_rooms"("room_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_rooms" ADD CONSTRAINT "FK_CHAT_ROOMS_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "customer_inquiries" ADD CONSTRAINT "FK_CI_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "diary_entries" ADD CONSTRAINT "FK_DE_PURCHASE" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("purchase_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "diary_entries" ADD CONSTRAINT "FK_DE_ROOM" FOREIGN KEY ("room_id") REFERENCES "chat_rooms"("room_id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "items" ADD CONSTRAINT "FK_ITEMS_CATEGORY" FOREIGN KEY ("category_id") REFERENCES "categories"("category_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "item_images" ADD CONSTRAINT "FK_II_ITEM" FOREIGN KEY ("item_id") REFERENCES "items"("item_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "login_histories" ADD CONSTRAINT "FK_LOGIN_HISTORIES_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "login_histories" ADD CONSTRAINT "FK_LH_DEVICE" FOREIGN KEY ("device_id") REFERENCES "user_devices"("device_id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notification_logs" ADD CONSTRAINT "FK_NOTIFICATION_LOGS_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notification_logs" ADD CONSTRAINT "FK_NL_TYPE" FOREIGN KEY ("notification_type_id") REFERENCES "notification_types"("notification_type_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "FK_PAY_PURCHASE" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("purchase_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "purchases" ADD CONSTRAINT "FK_PURCHASES_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "purchases" ADD CONSTRAINT "FK_PURCHASES_ITEM" FOREIGN KEY ("item_id") REFERENCES "items"("item_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "FK_SHIP_PURCHASE" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("purchase_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "FK_SHIP_ADDRESS" FOREIGN KEY ("address_id") REFERENCES "user_addresses"("address_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_addresses" ADD CONSTRAINT "FK_USER_ADDRESSES_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_consents" ADD CONSTRAINT "FK_UC_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_consents" ADD CONSTRAINT "FK_UC_TERM" FOREIGN KEY ("term_id") REFERENCES "terms"("term_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_devices" ADD CONSTRAINT "FK_UD_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_notification_settings" ADD CONSTRAINT "FK_UNS_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_notification_settings" ADD CONSTRAINT "FK_UNS_TYPE" FOREIGN KEY ("notification_type_id") REFERENCES "notification_types"("notification_type_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_social_accounts" ADD CONSTRAINT "FK_USA_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_withdrawals" ADD CONSTRAINT "FK_UW_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "weekly_sessions" ADD CONSTRAINT "FK_WEEKLY_SESSIONS_USER" FOREIGN KEY ("user_id") REFERENCES "users"("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- pgvector 인덱스 보류: HNSW/IVFFlat는 표준 vector 타입 기준 2000차원까지만 인덱싱 가능한데
-- content_vector는 3072차원(gemini-embedding-001 실측)이라 그대로는 인덱스 생성이 실패함.
-- 실제 유사도 검색 쿼리가 아직 코드베이스에 없어 지금은 인덱스 없이 컬럼만 둠.
-- 나중에 유사도 검색을 구현할 때 halfvec(3072) 캐스팅 + halfvec_cosine_ops 인덱스로 가는 걸 검토할 것.
