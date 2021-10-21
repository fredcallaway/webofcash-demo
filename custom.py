# this file imports custom routes into the experiment server

from flask import Blueprint, Response, render_template, abort, current_app, request, jsonify
from jinja2 import TemplateNotFound
from traceback import format_exc

from psiturk.psiturk_config import PsiturkConfig
from psiturk.user_utils import PsiTurkAuthorization, nocache
from psiturk.experiment_errors import ExperimentError

import json

# Database setup
from psiturk.db import db_session
from psiturk.models import Participant
from custom_models import StageOne

# load the configuration options
config = PsiturkConfig()
config.load_config()

# if you want to add a password protect route use this
myauth = PsiTurkAuthorization(config)

# explore the Blueprint
custom_code = Blueprint(
    'custom_code', __name__,
    template_folder='templates',
    static_folder='static')


@custom_code.route('/')
def demo():
    data = {
        key: "{{ " + key + " }}"
        for key in ['uniqueId', 'condition', 'counterbalance', 'adServerLoc', 'mode']
    }
    data['mode'] = 'demo'
    return render_template('exp.html', **data)

@custom_code.route('/test')
def test():
    data = {
        'uniqueId': 'uniqueId',
        'condition': 0,
        'counterbalance': 0,
        'adServerLoc': 'null',
        'mode': 'debug'
    }
    return render_template('exp.html', **data)


@custom_code.route('/create_stage1', methods=['POST'])
def create_stage1():
    try:
        current_app.logger.critical("create_stage1 %s", request.form)
        # workerid = str(request.form['workerid'])
        # return_time = str(request.form['return_time'])
        s1 = StageOne(request.form['workerid'], request.form['return_time'])
        db_session.add(s1)
        db_session.commit()
        return "success"
    except Exception as e:
        current_app.logger.error("error in stage1", exc_info=True)
        return str(e)

@custom_code.route('/check_stage1', methods=['GET'])
def check_stage1():
    try:
        workerid = str(request.args['workerid'])
        s1 = StageOne.query.filter(StageOne.workerid == workerid).first()
        current_app.logger.critical("s1 %s", s1)
        return str(s1.return_time)
    except Exception as e:
        current_app.logger.error("error in stage1", exc_info=True)
        return e
    # try:
    #     return render_template('custom.html')
    # except TemplateNotFound:
    #     abort(404)


# Status codes
NOT_ACCEPTED = 0
ALLOCATED = 1
STARTED = 2
COMPLETED = 3
SUBMITTED = 4
CREDITED = 5
QUITEARLY = 6
BONUSED = 7
BAD = 8


def get_participants(codeversion):
    participants = (Participant
        .query
        .filter(Participant.codeversion == codeversion)
        .filter(Participant.status > 2)
        .filter(Participant.mode != "debug")
        .all()
    )
    return participants


@custom_code.route('/data/<codeversion>/<name>', methods=['GET'])
@myauth.requires_auth
@nocache
def download_datafiles(codeversion, name):
    contents = {
        "trialdata": lambda p: p.get_trial_data(),
        "eventdata": lambda p: p.get_event_data(),
        "questiondata": lambda p: p.get_question_data()
    }

    if name not in contents:
        abort(404)

    query = get_participants(codeversion)
    data = []
    for p in query:
        try:
            data.append(contents[name](p))
        except TypeError:
            current_app.logger.error("Error loading {} for {}".format(name, p))
            current_app.logger.error(format_exc())
    ret = "".join(data)
    response = Response(
        ret,
        content_type="text/csv",
        headers={
            'Content-Disposition': 'attachment;filename=%s.csv' % name
        })

    return response


MAX_BONUS = 10

@custom_code.route('/compute_bonus', methods=['GET'])
def compute_bonus():
    # check that user provided the correct keys
    # errors will not be that gracefull here if being
    # accessed by the Javascrip client
    if not request.args.has_key('uniqueId'):
        raise ExperimentError('improper_inputs')

    # lookup user in database
    uniqueid = request.args['uniqueId']
    user = Participant.query.\
           filter(Participant.uniqueid == uniqueid).\
           one()

    final_bonus = 'NONE'
    # load the bonus information
    try:
        all_data = json.loads(user.datastring)
        question_data = all_data['questiondata']
        final_bonus = question_data['final_bonus']
        final_bonus = round(float(final_bonus), 2)
        if final_bonus > MAX_BONUS:
            raise ValueError('Bonus of {} excedes MAX_BONUS of {}'
                             .format(final_bonus, MAX_BONUS))
        user.bonus = final_bonus
        db_session.add(user)
        db_session.commit()

        resp = {
            'uniqueId': uniqueid,
            'bonusComputed': 'success',
            'bonusAmount': final_bonus
        }

    except:
        current_app.logger.error('error processing bonus for {}'.format(uniqueid))
        current_app.logger.error(format_exc())
        resp = {
            'uniqueId': uniqueid,
            'bonusComputed': 'failure',
            'bonusAmount': final_bonus
        }

    current_app.logger.info(str(resp))
    return jsonify(**resp)
