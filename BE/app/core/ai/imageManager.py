import io
import os
from dotenv import load_dotenv
from google import genai
from google.genai import types
from PIL import Image
from huggingface_hub import AsyncInferenceClient

# .env 파일의 환경변수를 로드합니다.
load_dotenv()

class ImageManager:
    def __init__(self):
        # 환경변수에서 키를 가져와 클라이언트를 초기화합니다.
        self.hf_token = os.getenv("FLUX_API_KEY")
        # 동기 InferenceClient를 쓰면 FLUX 응답을 기다리는 동안 이벤트 루프가 막혀
        # 그 서버 프로세스에 붙은 다른 모든 요청이 함께 정지한다. 비동기 클라이언트 필수.
        self.image_client = AsyncInferenceClient(
            provider="nscale",
            api_key=self.hf_token
        )

    async def generate_flux_image(self, image_prompt: str):
        """이미지 생성 AI 호출 (Core 계층의 역할)"""
        image = await self.image_client.text_to_image(
            image_prompt,
            model="black-forest-labs/FLUX.1-schnell"
        )
        return image

    async def generate_gemini_image(self, image_prompt: str):
        """Gemini 이미지 생성 호출. GEMINI_API_KEY를 그대로 쓰고, 결과는 PIL 이미지로 돌려준다."""
        client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        response = await client.aio.models.generate_content(
            model=os.getenv("GEMINI_IMAGE_MODEL", "gemini-2.5-flash-image"),
            contents=image_prompt,
            config=types.GenerateContentConfig(response_modalities=["IMAGE"]),
        )
        for part in response.candidates[0].content.parts:
            if part.inline_data and part.inline_data.data:
                return Image.open(io.BytesIO(part.inline_data.data))
        raise RuntimeError("Gemini 응답에 이미지가 없습니다")
