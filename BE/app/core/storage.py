import asyncio
import io
import os
import uuid

import boto3
from dotenv import load_dotenv

load_dotenv()

# S3 호환 오브젝트 스토리지에 생성 이미지를 보관한다.
# Render 무료 티어는 영구 디스크가 없어 재배포마다 로컬 파일이 사라지므로
# 로컬 저장(app/static/images) 대신 이쪽을 쓴다.
# 현재는 Supabase Storage를 쓰지만, 엔드포인트만 바꾸면 R2/S3에서도 동일하게 동작한다.

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = boto3.client(
            "s3",
            endpoint_url=os.environ["S3_ENDPOINT"],
            aws_access_key_id=os.environ["S3_ACCESS_KEY_ID"],
            aws_secret_access_key=os.environ["S3_SECRET_ACCESS_KEY"],
            region_name=os.environ["S3_REGION"],
        )
    return _client


def _key_from_url(image_url: str) -> str:
    # 공개 URL은 버킷 경로까지 포함한 접두사 + 키로 구성된다.
    # urlparse로 path를 그대로 쓰면 Supabase처럼 접두사가 긴 경우
    # storage/v1/object/public/... 까지 키로 잘못 잡힌다.
    base = os.environ["S3_PUBLIC_BASE_URL"].rstrip("/") + "/"
    return image_url.removeprefix(base)


async def upload_image(image) -> str:
    """PIL 이미지를 업로드하고 공개 URL을 반환한다."""
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    key = f"images/{uuid.uuid4()}.png"

    # boto3는 동기 라이브러리라 그대로 호출하면 이벤트 루프가 막혀
    # 같은 프로세스의 다른 요청까지 함께 정지한다. 별도 스레드로 넘긴다.
    await asyncio.to_thread(
        _get_client().put_object,
        Bucket=os.environ["S3_BUCKET"],
        Key=key,
        Body=buffer.getvalue(),
        ContentType="image/png",
    )

    return f"{os.environ['S3_PUBLIC_BASE_URL'].rstrip('/')}/{key}"


async def delete_image(image_url: str) -> None:
    """업로드된 이미지를 URL 기준으로 삭제한다."""
    await asyncio.to_thread(
        _get_client().delete_object,
        Bucket=os.environ["S3_BUCKET"],
        Key=_key_from_url(image_url),
    )
