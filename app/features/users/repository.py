from datetime import UTC, datetime

from sqlalchemy import distinct, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.auth.models import RefreshToken
from app.features.users.models import User


class UserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, user_id: int) -> User | None:
        result = await self.session.execute(
            select(User).where(User.user_id == user_id),
        )

        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self.session.execute(
            select(User).where(User.email == email),
        )

        return result.scalar_one_or_none()

    async def admin_directory(
        self, *, search: str | None, limit: int, offset: int
    ) -> tuple[int, int, int, list[User], set[int]]:
        now = datetime.now(UTC)
        total_users = await self.session.scalar(select(func.count(User.user_id))) or 0
        signed_in_users = await self.session.scalar(
            select(func.count(distinct(RefreshToken.user_id)))
            .join(User, User.user_id == RefreshToken.user_id)
            .where(
                User.is_active.is_(True),
                RefreshToken.revoked_at.is_(None),
                RefreshToken.expires_at > now,
            )
        ) or 0

        condition = None
        if search:
            pattern = f"%{search.strip()}%"
            condition = or_(User.full_name.ilike(pattern), User.email.ilike(pattern))
        count_query = select(func.count(User.user_id))
        users_query = select(User)
        if condition is not None:
            count_query = count_query.where(condition)
            users_query = users_query.where(condition)
        matching_users = await self.session.scalar(count_query) or 0
        users = list(
            (await self.session.scalars(
                users_query.order_by(func.lower(User.full_name), User.user_id)
                .limit(limit)
                .offset(offset)
            )).all()
        )
        if not users:
            return total_users, signed_in_users, matching_users, users, set()
        active_ids = set(
            (await self.session.scalars(
                select(RefreshToken.user_id)
                .where(
                    RefreshToken.user_id.in_([user.user_id for user in users]),
                    RefreshToken.revoked_at.is_(None),
                    RefreshToken.expires_at > now,
                )
                .distinct()
            )).all()
        )
        return total_users, signed_in_users, matching_users, users, active_ids

    async def create(
        self,
        *,
        full_name: str,
        email: str,
        password_hash: str,
        role: str,
        avatar_url: str | None = None,
    ) -> User:
        user = User(
            full_name=full_name,
            email=email,
            password_hash=password_hash,
            role=role,
            avatar_url=avatar_url,
        )
        self.session.add(user)
        await self.session.flush()

        return user

    async def update_profile(
        self,
        *,
        user: User,
        full_name: str | None = None,
        avatar_url: str | None = None,
    ) -> User:
        if full_name is not None:
            user.full_name = full_name

        if avatar_url is not None:
            user.avatar_url = avatar_url

        await self.session.flush()

        return user
