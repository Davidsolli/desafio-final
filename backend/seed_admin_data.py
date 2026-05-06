import asyncio
from app.services.user_service import UserService
from app.config.database import _get_async_session_local
from app.dtos.user_dto import CreateUserDTO

async def seed():
    session_local = _get_async_session_local()
    async with session_local() as session:
        service = UserService(session)

        print("Seeding admin e trainers...")

        # Criar admin
        try:
            admin_dto = CreateUserDTO(
                name='Admin Master',
                email='admin@fitloop.com',
                password='Admin@12345',
                role='admin',
            )
            admin = await service.create(admin_dto)
            print(f'✓ Admin criado: {admin.name} ({admin.email})')
        except Exception as e:
            print(f'✗ Erro ao criar admin: {e}')

        # Criar 3 trainers
        trainers_data = [
            {'name': 'João Silva', 'email': 'joao@fitloop.com', 'password': 'Trainer@123'},
            {'name': 'Maria Santos', 'email': 'maria@fitloop.com', 'password': 'Trainer@123'},
            {'name': 'Pedro Costa', 'email': 'pedro@fitloop.com', 'password': 'Trainer@123'},
        ]

        for trainer_data in trainers_data:
            try:
                trainer_dto = CreateUserDTO(
                    **trainer_data,
                    role='personal_trainer',
                )
                trainer = await service.create(trainer_dto)
                print(f'✓ Trainer criado: {trainer.name} ({trainer.email})')
            except Exception as e:
                print(f'✗ Erro ao criar trainer: {e}')

if __name__ == '__main__':
    asyncio.run(seed())
