"""
Testes unitários para fórmulas de composição corporal.
Testam os métodos estáticos do BodyMeasurementService sem banco de dados.
"""

from datetime import date

import pytest

from app.services.body_measurement_service import BodyMeasurementService, ACTIVITY_FACTORS


class TestCalculateBMI:
    def test_bmi_correct(self):
        # 85.5 / 1.75² = 27.9...
        result = BodyMeasurementService.calculate_bmi(85.5, 175.0)
        assert result == pytest.approx(27.9, abs=0.1)

    def test_bmi_normal_weight(self):
        # 70 / 1.75² ≈ 22.9
        result = BodyMeasurementService.calculate_bmi(70.0, 175.0)
        assert 18.5 <= result <= 24.9

    def test_bmi_rounds_to_one_decimal(self):
        result = BodyMeasurementService.calculate_bmi(80.0, 180.0)
        assert result == round(result, 1)


class TestCalculateBMR:
    def test_bmr_male(self):
        # Homem 85kg, 175cm, 30 anos
        # TMB = (10*85) + (6.25*175) - (5*30) + 5 = 850 + 1093.75 - 150 + 5 = 1798.75
        result = BodyMeasurementService.calculate_bmr(85.0, 175.0, 30, "male")
        assert result == pytest.approx(1798.75, abs=0.5)

    def test_bmr_female(self):
        # Mulher 65kg, 165cm, 28 anos
        # TMB = (10*65) + (6.25*165) - (5*28) - 161 = 650 + 1031.25 - 140 - 161 = 1380.25
        result = BodyMeasurementService.calculate_bmr(65.0, 165.0, 28, "female")
        assert result == pytest.approx(1380.25, abs=0.5)

    def test_bmr_male_higher_than_female_same_params(self):
        bmr_male = BodyMeasurementService.calculate_bmr(70.0, 170.0, 25, "male")
        bmr_female = BodyMeasurementService.calculate_bmr(70.0, 170.0, 25, "female")
        assert bmr_male > bmr_female


class TestCalculateTDEE:
    def test_tdee_all_activity_levels(self):
        bmr = 1800.0
        expected = {
            "sedentary": pytest.approx(1800 * 1.2, abs=0.5),
            "light": pytest.approx(1800 * 1.375, abs=0.5),
            "moderate": pytest.approx(1800 * 1.55, abs=0.5),
            "active": pytest.approx(1800 * 1.725, abs=0.5),
            "very_active": pytest.approx(1800 * 1.9, abs=0.5),
        }
        for level, expected_value in expected.items():
            result = BodyMeasurementService.calculate_tdee(bmr, level)
            assert result == expected_value, f"Falhou para activity_level={level}"

    def test_tdee_increases_with_activity(self):
        bmr = 2000.0
        levels = ["sedentary", "light", "moderate", "active", "very_active"]
        values = [BodyMeasurementService.calculate_tdee(bmr, lvl) for lvl in levels]
        assert values == sorted(values), "TDEE deve aumentar conforme nível de atividade"


class TestCalculateAge:
    def test_age_known_date(self):
        # Nasceu em 1990-01-01, hoje é 2026-04-29 → 36 anos
        birth = date(1990, 1, 1)
        age = BodyMeasurementService.calculate_age(birth)
        assert age == 36

    def test_age_birthday_not_yet(self):
        # Nasceu em 1990-12-31, hoje é 2026-04-29 → 35 anos (aniversário ainda não passou)
        birth = date(1990, 12, 31)
        age = BodyMeasurementService.calculate_age(birth)
        assert age == 35

    def test_age_is_positive(self):
        birth = date(2000, 6, 15)
        age = BodyMeasurementService.calculate_age(birth)
        assert age > 0
