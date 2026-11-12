from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


ExpenseCategory = Literal[
    "transportation",
    "accommodation",
    "meals",
    "activities",
    "other",
]
ExpenseStatus = Literal["active", "voided"]
ExpenseSplitMethod = Literal["equal"]
Money = Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]
PositiveMoney = Annotated[Decimal, Field(gt=0, max_digits=10, decimal_places=2)]


class TripExpenseCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    category: ExpenseCategory
    amount: PositiveMoney
    paid_by_trip_member_id: int = Field(ge=1)
    expense_date: date | None = None
    notes: str | None = None
    split_method: ExpenseSplitMethod = "equal"


class TripExpenseUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    category: ExpenseCategory | None = None
    amount: PositiveMoney | None = None
    paid_by_trip_member_id: int | None = Field(default=None, ge=1)
    expense_date: date | None = None
    notes: str | None = None

    @field_validator(
        "title",
        "category",
        "amount",
        "paid_by_trip_member_id",
        "expense_date",
        mode="before",
    )
    @classmethod
    def required_fields_cannot_be_null(cls, value):
        if value is None:
            raise ValueError("Field cannot be null when provided.")

        return value


class TripExpenseSplitResponse(BaseModel):
    trip_expense_split_id: int
    trip_expense_id: int
    trip_member_id: int
    user_id: int
    full_name: str
    email: EmailStr
    share_amount: Decimal
    created_at: datetime


class TripExpenseResponse(BaseModel):
    trip_expense_id: int
    trip_id: int
    paid_by_trip_member_id: int
    paid_by_user_id: int
    paid_by_full_name: str
    paid_by_email: EmailStr
    created_by_user_id: int
    category: ExpenseCategory
    title: str
    description: str | None
    amount: Decimal
    expense_date: date
    split_method: ExpenseSplitMethod
    status: ExpenseStatus
    notes: str | None
    splits: list[TripExpenseSplitResponse]
    created_at: datetime
    updated_at: datetime


class TripExpenseCategoryBreakdown(BaseModel):
    category: ExpenseCategory
    total: Decimal


class TripExpenseMemberBalance(BaseModel):
    trip_member_id: int
    user_id: int
    full_name: str
    email: EmailStr
    paid_total: Decimal
    share_total: Decimal
    net_balance: Decimal


class TripExpenseSummaryResponse(BaseModel):
    trip_id: int
    total_budget: Decimal
    total_spent: Decimal
    remaining_budget: Decimal
    over_budget_amount: Decimal
    is_over_budget: bool
    category_breakdown: list[TripExpenseCategoryBreakdown]
    member_balances: list[TripExpenseMemberBalance]
