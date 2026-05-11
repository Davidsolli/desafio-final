from typing import List, Optional, Any
from pydantic import BaseModel, ConfigDict
from datetime import time, datetime
from uuid import UUID

class UpdateNotificationPreferenceDTO(BaseModel):
    notifications_enabled: Optional[bool] = None
    workout_reminder_enabled: Optional[bool] = None
    workout_reminder_time: Optional[time] = None
    meal_reminder_enabled: Optional[bool] = None
    meal_reminder_time: Optional[time] = None
    new_workout_sheet_enabled: Optional[bool] = None
    achievement_enabled: Optional[bool] = None
    performance_report_enabled: Optional[bool] = None
    quiet_hours_start: Optional[time] = None
    quiet_hours_end: Optional[time] = None
    silent_days: Optional[List[int]] = None


class NotificationPreferenceResponseDTO(BaseModel):
    id: UUID
    user_id: UUID
    notifications_enabled: bool
    workout_reminder_enabled: bool
    workout_reminder_time: Optional[time]
    meal_reminder_enabled: bool
    meal_reminder_time: Optional[time]
    new_workout_sheet_enabled: bool
    achievement_enabled: bool
    performance_report_enabled: bool
    quiet_hours_start: Optional[time]
    quiet_hours_end: Optional[time]
    silent_days: Optional[List[int]]

    model_config = ConfigDict(from_attributes=True)


class NotificationLogResponseDTO(BaseModel):
    id: UUID
    user_id: UUID
    notification_type: str
    title: str
    body: str
    data: Optional[dict[str, Any]]
    sent_at: Optional[datetime]
    read_at: Optional[datetime]
    clicked_at: Optional[datetime]
    status: str
    error: Optional[str]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class MarkNotificationReadDTO(BaseModel):
    notification_id: UUID


class UpdateFCMTokenDTO(BaseModel):
    fcm_token: str
