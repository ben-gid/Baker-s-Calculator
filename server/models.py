from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List

class UserPublic(SQLModel):
    id: int
    username: str
    email: str

class UserCreate(SQLModel):
    username: str
    email: str
    password: str

class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    username: str = Field(unique=True, index=True)
    email: str = Field(unique=True, index=True)
    hashed_password: str
    recipes: List["Recipe"] = Relationship(back_populates="user")

class Recipe(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    title: str = Field(index=True)
    description: Optional[str] = None
    doughType: str
    payload: str  # JSON string of the recipe details
    user_id: Optional[int] = Field(default=None, foreign_key="user.id")
    user: Optional[User] = Relationship(back_populates="recipes")

class Token(SQLModel):
    access_token: str
    token_type: str
