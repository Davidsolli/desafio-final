from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class BodyMeasurement(Base):
    __tablename__ = "body_measurements"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)

    weight_kg = Column(Float, nullable=False)
    height_cm = Column(Float, nullable=False)

    chest_cm = Column(Float, nullable=True)
    waist_cm = Column(Float, nullable=True)
    hip_cm = Column(Float, nullable=True)
    thigh_cm = Column(Float, nullable=True)
    arm_cm = Column(Float, nullable=True)

    body_fat_percentage = Column(Float, nullable=True)

    bmi = Column(Float, nullable=False)
    bmr_kcal = Column(Float, nullable=False)
    tdee_kcal = Column(Float, nullable=False)

    activity_level = Column(String(20), nullable=False)

    measured_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<BodyMeasurement(id={self.id}, user_id={self.user_id}, bmi={self.bmi})>"
