from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, Query, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlmodel import Session, select
from database import create_db_and_tables, get_session
from models import Recipe, User, UserCreate, UserPublic, Token
from typing import List
from auth import verify_password, get_password_hash, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES, SECRET_KEY, ALGORITHM
from datetime import timedelta
import jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    yield

app = FastAPI(lifespan=lifespan, title="Baker's Calculator API")

def get_current_user(token: str = Depends(oauth2_scheme), session: Session = Depends(get_session)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except jwt.InvalidTokenError:
        raise credentials_exception
    user = session.exec(select(User).where(User.username == username)).first()
    if user is None:
        raise credentials_exception
    return user

@app.post("/register", response_model=UserPublic)
def register(user_in: UserCreate, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.username == user_in.username)).first()
    if user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    hashed_password = get_password_hash(user_in.password)
    db_user = User(username=user_in.username, email=user_in.email, hashed_password=hashed_password)
    session.add(db_user)
    session.commit()
    session.refresh(db_user)
    return db_user

@app.post("/token", response_model=Token)
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.username == form_data.username)).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/users/me", response_model=UserPublic)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@app.post("/recipes/", response_model=Recipe)
def create_recipe(recipe: Recipe, current_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    recipe.user_id = current_user.id
    session.add(recipe)
    session.commit()
    session.refresh(recipe)
    return recipe

@app.get("/recipes/", response_model=List[Recipe])
def read_recipes(skip: int = 0, limit: int = Query(default=100, le=100), current_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    recipes = session.exec(select(Recipe).where(Recipe.user_id == current_user.id).offset(skip).limit(limit)).all()
    return recipes

@app.get("/recipes/{recipe_id}", response_model=Recipe)
def read_recipe(recipe_id: int, current_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    recipe = session.get(Recipe, recipe_id)
    if not recipe or recipe.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return recipe

@app.delete("/recipes/{recipe_id}")
def delete_recipe(recipe_id: int, current_user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    recipe = session.get(Recipe, recipe_id)
    if not recipe or recipe.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Recipe not found")
    session.delete(recipe)
    session.commit()
    return {"ok": True}
