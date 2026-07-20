from app.core.ai.reportManager import ReportManager
from app.repositories.reportRepository import ReportRepository

class ReportService:
    def __init__(self):
        self.report_repo = ReportRepository()
        self.ai_manager = ReportManager()

    async def generate_and_save_report(self, user_id: int):
        # 1. 최근 꿈 3개 가져오기
        sessions = await self.report_repo.get_latest_sessions(user_id, 3)
        
        if not sessions:
            raise ValueError("분석할 꿈 기록이 존재하지 않습니다.")

        # 2. AI에게 먹일 텍스트 조립하기 (본문 있는 방만 조회되지만 빈 문자열은 방어)
        dreams_text_list = []
        for i, session in enumerate(sessions):
            content = session.content or "내용 없음"
            dreams_text_list.append(f"[꿈 {i+1}] 날짜: {session.created_at} \n내용: {content}")
            
        combined_dreams_text = "\n\n".join(dreams_text_list)

        # 3. AI 분석 실행
        analysis_result = await self.ai_manager.generate_insight(combined_dreams_text)

        # 4. 분석된 꿈들의 첫 날짜와 마지막 날짜 계산 (sessions는 최신순이므로 [-1]이 가장 옛날)
        start_date = sessions[-1].created_at
        end_date = sessions[0].created_at

        # 5. DB에 Weekly Session 생성
        saved_report = await self.report_repo.create_weekly_session(
            user_id=user_id,
            content=analysis_result,
            start_date=start_date,
            end_date=end_date
        )

        return saved_report
    
    async def get_user_report(self, user_id: int):
        report = await self.report_repo.get_latest_weekly_session(user_id)
        
        # 리포트가 아예 없을 수도 있으므로 None을 그대로 반환하여 프론트에서 처리하게 함
        return report