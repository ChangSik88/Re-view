import os
from dotenv import load_dotenv
from huggingface_hub import InferenceClient

# .env 파일의 환경변수를 로드합니다.
load_dotenv()

class ImageManager:
    def __init__(self):
        # 환경변수에서 키를 가져와 클라이언트를 초기화합니다.
        self.hf_token = os.getenv("FLUX_API_KEY")
        self.image_client = InferenceClient(
            provider="nscale", 
            api_key=self.hf_token
        )

    async def generate_flux_image(self, image_prompt: str):
        """이미지 생성 AI 호출 (Core 계층의 역할)"""
        image = self.image_client.text_to_image(
            image_prompt, 
            model="black-forest-labs/FLUX.1-schnell"
        )
        return image