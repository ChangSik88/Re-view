"""태그 카드 사진 원본 폴더를 웹용 WebP로 바꿔 BE/app/static/tagImages/normal/에 넣는다.

사용법 (venv 활성화 후 저장소 루트에서):
    python BE/scripts/build_tag_images.py "<원본 폴더>"

원본 파일명은 "번호.태그id.png"(예: "7.갑작스러운 타격.png")이고, 저장 파일명은
dream_tags.json의 image_key다(예: tag_sudden_blow.webp). 태그 목록과 파일이 하나라도
어긋나면(누락, 여분, 중복, 파일명 형식, 비율) 아무것도 쓰지 않고 실패한다.
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

from PIL import Image

BE_DIR = Path(__file__).resolve().parents[1]
TAGS_FILE = BE_DIR / "app" / "data" / "dream_tags.json"
OUT_DIR = BE_DIR / "app" / "static" / "tagImages" / "normal"

# 원본 해상도 그대로(더 키우면 확대라 선명해지지 않는다). 웹 카드 폭 306px을 3배 화면에서도
# 덮는다. 원본 비율 2:3을 그대로 둔다. 사진에 카드 테두리와 글자가 그려져 있어 잘라 내면 테두리가 깨진다.
SIZE = (1024, 1536)
QUALITY = 75
FILE_PATTERN = re.compile(r"^(\d+)\.(.+)\.png$", re.IGNORECASE)


def main(src_dir: Path) -> None:
    tags = json.loads(TAGS_FILE.read_text(encoding="utf-8"))["tags"]
    key_by_id = {unicodedata.normalize("NFC", tag["id"]): tag["image_key"] for tag in tags}

    errors: list[str] = []
    found: dict[str, Path] = {}
    for path in sorted(src_dir.iterdir()):
        if not path.is_file():
            continue
        match = FILE_PATTERN.match(unicodedata.normalize("NFC", path.name))
        if not match:
            errors.append(f"파일명 형식이 \"번호.태그id.png\"가 아님: {path.name}")
            continue
        tag_id = match.group(2)
        if tag_id not in key_by_id:
            errors.append(f"태그 목록에 없는 파일(여분): {path.name}")
        elif tag_id in found:
            errors.append(f"같은 태그 파일이 두 개: {found[tag_id].name}, {path.name}")
        else:
            found[tag_id] = path

    for tag_id in key_by_id:
        if tag_id not in found:
            errors.append(f"사진이 없는 태그(누락): {tag_id}")

    for tag_id, path in found.items():
        with Image.open(path) as image:
            width, height = image.size
        if abs(width * SIZE[1] - height * SIZE[0]) > width * SIZE[1] * 0.01:
            errors.append(f"비율이 2:3이 아님({width}x{height}): {path.name}")

    if errors:
        print("실패. 아무것도 쓰지 않았습니다.")
        print("\n".join(f"- {error}" for error in errors))
        sys.exit(1)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    expected = {f"{key}.webp" for key in key_by_id.values()}
    for old in OUT_DIR.glob("*.webp"):
        if old.name not in expected:
            old.unlink()

    total = 0
    for tag_id, path in found.items():
        out_path = OUT_DIR / f"{key_by_id[tag_id]}.webp"
        with Image.open(path) as image:
            image.convert("RGB").resize(SIZE, Image.LANCZOS).save(out_path, "WEBP", quality=QUALITY, method=6)
        total += out_path.stat().st_size

    print(f"{len(found)}장 저장: {OUT_DIR} (합계 {total // 1024} KB)")


if __name__ == "__main__":
    if len(sys.argv) != 2 or not Path(sys.argv[1]).is_dir():
        print(__doc__)
        sys.exit(2)
    main(Path(sys.argv[1]))
