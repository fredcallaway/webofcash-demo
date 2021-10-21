from psiturk.db import Base, db_session, init_db
from sqlalchemy import or_, Column, Integer, String, DateTime, Boolean, Float, Text, ForeignKey
from sqlalchemy.orm import relationship, backref
# import shortuuid


class StageOne(Base):
    """
    DB for tracking workers who completed stage one.
    """
    index = Column(Integer, primary_key=True, unique=True)
    __tablename__ = 'stage_one'
    workerid = Column(String(128))
    return_time = Column(String(128))

    def __init__(self, workerid, return_time):
        self.workerid = workerid
        self.return_time  = return_time