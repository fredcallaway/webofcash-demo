###
jspsych-mouselab-mdp.coffee
Fred Callaway

https://github.com/fredcallaway/Mouselab-MDP
###

# coffeelint: disable=max_line_length,no_unnecessary_fat_arrows
mdp = undefined
FOO = undefined
WATCH = {}
SCORE = 0
TIME_LEFT = undefined

jsPsych.plugins['mouselab-mdp'] = do ->

  PRINT = (args...) -> console.log args...
  NULL = (args...) -> null
  LOG_INFO = PRINT
  LOG_DEBUG = NULL

  # a scaling parameter, determines size of drawn objects
  SIZE = undefined
  TRIAL_INDEX = 0
  STATE_COLOR = 'hsl(0, 0%, 75%)'
  # STATE_COLOR = '#bbbbbb'
  TOP_ADJUST = -16
  DEMO_MODEL = 'OptimalPlus'
  NEUTRAL_COLOR = 120

  fabric.Object::originX = fabric.Object::originY = 'center'
  fabric.Object::selectable = false
  fabric.Object::hoverCursor = 'plain'

  # =========================== #
  # ========= Helpers ========= #
  # =========================== #

  waitKey = (keys=['space']) -> new Promise (resolve) ->
    jsPsych.pluginAPI.getKeyboardResponse
      valid_responses: keys
      persist: false
      allow_held_key: true
      callback_function: (info) =>
        resolve()

  removePrivate = (obj) ->
    _.pick obj, ((v, k, o) -> not k.startsWith('_'))

  angle = (x1, y1, x2, y2) ->
    x = x2 - x1
    y = y2 - y1
    if x == 0
      ang = if y == 0 then 0 else if y > 0 then Math.PI / 2 else Math.PI * 3 / 2
    else if y == 0
      ang = if x > 0 then 0 else Math.PI
    else
      ang = if x < 0
        Math.atan(y / x) + Math.PI
      else if y < 0
        Math.atan(y / x) + 2 * Math.PI
      else Math.atan(y / x)
    return ang + Math.PI / 2

  polarMove = (x, y, ang, dist) ->
    x += dist * Math.sin ang
    y -= dist * Math.cos ang
    return [x, y]

  dist = (o1, o2) ->
    ((o1.left - o2.left) ** 2 + (o1.top - o2.top)**2) ** 0.5

  redGreen = (val) ->
    if val == 'X'
      '#357ebd'
    else if val > 0
      '#080'
    else if val < 0
      '#b00'
    else
      '#666'

  round = (x) ->
    (Math.round (x * 100)) / 100

  checkObj = (obj, keys) ->
    if not keys?
      keys = Object.keys(obj)
    for k in keys
      if obj[k] is undefined
        console.log 'Bad Object: ', obj
        throw new Error "#{k} is undefined"
    obj

  KEYS = mapObject
    up: 'uparrow'
    down: 'downarrow',
    right: 'rightarrow',
    left: 'leftarrow',
    simulate: 'space'
    jsPsych.pluginAPI.convertKeyCharacterToKeyCode
  
  RIGHT_MESSAGE = '\xa0'.repeat(8) + 'Score: <span id=mouselab-score/>'

  remove = (list, i) ->
    list = list.slice()
    list.splice(i,1)
    return list

# =============================== #
# ========= MouselabMDP ========= #
# =============================== #
  
  class MouselabMDP
    constructor: (config) ->
      {
        @display  # html display element
        
        @graph  # defines transition and reward functions
        @layout  # defines position of states
        @initial  # initial state of player

        @stateLabels='reward'  # object mapping from state names to labels
        @stateDisplay='never'  # one of 'never', 'hover', 'click', 'always'
        @stateClickCost=0  # subtracted from score every time a state is clicked
        @edgeLabels='never'  # object mapping from edge names (s0 + '__' + s1) to labels
        @edgeDisplay='always'  # one of 'never', 'hover', 'click', 'always'
        @edgeClickCost=0  # subtracted from score every time an edge is clicked
        @stateRewards=null

        @clickDelay=0
        @moveDelay=500
        @clickEnergy=0
        @moveEnergy=0
        @startScore=0

        @exampleOnly=false
        @demo=null
        @comprehension=false
        @examples=null

        @expandOnly=true
        @allowSimulation=false
        @revealRewards=true
        @special=''
        @minClicks=0
        @timeLimit=null
        @minTime=null
        @energyLimit=null

        # @transition=null  # function `(s0, a, s1, r) -> null` called after each transition
        @keys=KEYS  # mapping from actions to keycodes
        @trialIndex=TRIAL_INDEX  # number of trial (starts from 1)
        @playerImage='static/images/plane.png'
        size=80  # determines the size of states, text, etc...

        # leftMessage="Round: #{TRIAL_INDEX}/#{N_TRIAL}"
        trial_id=null
        blockName='none'
        prompt='&nbsp;'
        leftMessage=null
        centerMessage='&nbsp;'
        rightMessage=RIGHT_MESSAGE
        lowerMessage='&nbsp;'
      } = config

      SIZE = size

      _.extend this, config
      checkObj this

      if @comprehension
        lowerMessage = '&nbsp;'
        @clickedNodes = Array(_.size @graph).fill false
        @numTries = 3
        @exampleIdx = 0
        prompt = """
        <h1>Quiz</h1>

        Please click on every node that
        could have a value of #{BEST_VAL}. You can click a node again
        to unselect it.
        """
        leftMessage = rightMessage = ""

      else if @exampleOnly
        leftMessage = rightMessage = ""
        lowerMessage = '&nbsp;'
        @exampleIdx = 0
        @stateDisplay = 'never'
      else
        if @stateLabels is 'reward'
          @stateLabels = @stateRewards
          @stateLabels[0] = ''

        unless leftMessage
          if @energyLimit
            leftMessage = 'Energy: <b><span id=mouselab-energy/></b>'
            if not @_block.energyLeft?
              @_block.energyLeft = @energyLimit
          else
            leftMessage = "Round #{@_block.trialCount + 1}/#{@_block.timeline.length}"
          # leftMessage = "Round #{@_block.trialCount + 1}/#{@_block.timeline.length}"

      @data =
        stateRewards: @stateRewards
        comprehension: []
        trial_id: trial_id
        block: blockName
        trialIndex: @trialIndex
        score: 0
        simulationMode: []
        rewards: []
        path: []
        rt: []
        actions: []
        actionTimes: []
        queries: {
          click: {
            state: {'target': [], 'time': []}
            edge: {'target': [], 'time': []}
          }
          mouseover: {
            state: {'target': [], 'time': []}
            edge: {'target': [], 'time': []}
          }
          mouseout: {
            state: {'target': [], 'time': []}
            edge: {'target': [], 'time': []}
          }
        }

      if $('#mouselab-msg-right').length  # right message already exists
        @leftMessage = $('#mouselab-msg-left')
        @leftMessage.html leftMessage
        @centerMessage = $('#mouselab-msg-center')
        @centerMessage.html centerMessage
        @rightMessage = $('#mouselab-msg-right')
        @rightMessage.html rightMessage
        @stage = $('#mouselab-stage')
        @prompt = $('#mouselab-prompt')
        @prompt.html prompt
        # @canvasElement = $('#mouselab-canvas')
        # @lowerMessage = $('#mouselab-msg-bottom')
      else
        do @display.empty
        # @display.css 'width', '1000px'

        # leftMessage = "Round: #{@trialIndex + 1}/#{@_block.timeline.length}"
        unless prompt is null
          @prompt = $('<div>',
            id: 'mouselab-prompt'
            class: 'mouselab-prompt'
            html: prompt).appendTo @display

        @leftMessage = $('<div>',
          id: 'mouselab-msg-left'
          class: 'mouselab-header'
          html: leftMessage).appendTo @display

        @centerMessage = $('<div>',
          id: 'mouselab-msg-center'
          class: 'mouselab-header'
          html: centerMessage).appendTo @display

        @rightMessage = $('<div>',
          id: 'mouselab-msg-right',
          class: 'mouselab-header'
          html: rightMessage).appendTo @display

        @stage = $('<div>',
          id: 'mouselab-stage').appendTo @display
        if @timeLimit
          TIME_LEFT = @timeLimit

        @addScore @startScore
      # -----------------------------

      @canvasElement = $('<canvas>',
        id: 'mouselab-canvas',
      ).attr(width: 500, height: 500).appendTo @stage

      @lowerMessage = $('<div>',
        id: 'mouselab-msg-bottom'
        class: 'mouselab-msg-bottom'
        html: lowerMessage or '&nbsp'
      ).appendTo @stage

      @waitMessage = $('<div>',
        id: 'mouselab-wait-msg'
        class: 'mouselab-msg-bottom'
        # html: """Please wait <span id='mdp-time'></span> seconds"""
      ).appendTo @display

      @waitMessage.hide()
      @defaultLowerMessage = lowerMessage

      mdp = this
      LOG_INFO 'new MouselabMDP', this
      @invKeys = _.invert @keys
      @resetScore()
      @spendEnergy 0
      @freeze = false
      @lowerMessage.css 'color', '#000'

      if @comprehension or @exampleOnly
        @examplesLeft = -1
        @comprehensionButton = $ '<button>',
          text: 'Submit'
          class: 'btn btn-primary btn-lg'
          click: =>
            if @examplesLeft > 0
              @showExample()
              @comprehensionButton.prop "disabled", true
              await sleep 1500
              @comprehensionButton.prop "disabled", false
            else if @examplesLeft == 0
              if @exampleOnly
                do @finishTrial
              else
                @clearExample()
                @examplesLeft -= 1
            else
              @comprehensionCheck()
        console.log 'here I am'
        @lowerMessage.append @comprehensionButton

  

    # showDistribution: (dist) =>
    #   dist = remove(dist, 1)
    #   for [d, s] in _.zip(dist, _.values(@states))
    #     s.circle.setColor "hsl(0, #{100*d}%, 75%)"
    #   @canvas.renderAll()

    comprehensionCheck: =>
      attempt =
        correct: _.isEqual @clickedNodes, @selectNodes
        clickedNodes: @clickedNodes.slice()
      @clickedNodes = Array(_.size @graph).fill false
      @data.comprehension.push attempt

      if attempt.correct
        @data.trialTime = getTime() - @initTime
        jsPsych.finishTrial @data
      else
        @numTries -= 1
        if @numTries <= 0
          @comprehensionFailed()
        else
          @comprehensionAgain()

    comprehensionAgain: =>
      @examplesLeft = 5
      $('<div>',
        class: 'modal'
        html: $('<div>',
          class: 'modal-content'
          html: """
            <h2>Not quite</h2>

            <p>
            Take a look at a few more examples and try again.
            <br>
            <b>You have #{@numTries} attempts remaining</b>
          """
      )).appendTo @display
      $('<button>',
        text: 'See Examples'
        class: 'btn btn-primary btn-lg'
        click: =>
          $('.modal').remove()
          @showExample()
      ).appendTo $('.modal-content')

    comprehensionFailed: =>
      $('<div>',
        class: 'modal'
        html: $('<div>',
          class: 'modal-content'
          html: """
            <h2>Disqualified</h2>

            <p>
            Sorry, you exceeded the maximum number of attempts.
            This disqualifies you from completing the experiment. You will still
            receive the base pay. Please click the button below to submit.
          """
      )).appendTo @display
      $('<button>',
        text: 'Submit HIT'
        class: 'btn btn-primary btn-lg'
        click: =>
          @display.html ''
          $('.modal').remove()
          $('#load-icon').show()
          jsPsych.endExperiment()
          jsPsych.finishTrial @data
            
      ).appendTo $('.modal-content')

    showExample: =>
      if @exampleOnly
        @leftMessage.html "Example: #{@exampleIdx + 1}/#{@examples.length}"

      if @examplesLeft == 1
        @comprehensionButton.text 'Continue'
      else
        @comprehensionButton.text 'Next Example'
      rewards = @examples[@exampleIdx].stateRewards
      for s, g of @states
        if s isnt "0"
          g.setLabel rewards[s]
      @canvas.renderAll()
      @exampleIdx = (@exampleIdx + 1) % @examples.length
      @examplesLeft -= 1

    clearExample: =>

      @comprehensionButton.text 'Submit'
      for s, g of @states
        g.setLabel ''
      @canvas.renderAll()

    showPredictions: =>
      switch DEMO_MODEL
        when 'None'
          for s in _.values @states
            s.circle.setColor STATE_COLOR

        when 'Difference'
          opt = remove(@demo.predictions["Optimal"][@demo_i], 1)
          bf = remove(@demo.predictions["BestFirst"][@demo_i], 1)
          diff = _.zip(opt, bf).map ([a, b]) -> a - b
          max = _.zip(opt, bf).map ([a, b]) -> Math.max(a, b)

          for [m, d, s] in _.zip(max, diff, _.values(@states))
            # hue = NEUTRAL_COLOR + 90 * d
            # sat = m
            hue = NEUTRAL_COLOR + 90 * Math.sign(d)
            sat = Math.abs d
            sat = Math.max(0, Math.min(1, sat * 1.5))
            # light = 0.1 + 0.8 * (1 - m)
            light = .75
            s.circle.setColor "hsl(#{hue}, #{100*sat}%, #{light*100}%)"
            s.circle.setShadow
              blur: 0

        else
          pred = remove(@demo.predictions[DEMO_MODEL][@demo_i], 1)
          for [v, s] in _.zip(pred, _.values(@states))
            s.circle.setColor "hsl(210, #{100*v}%, 75%)"
            s.circle.setShadow
              blur: 0
    
      @canvas.renderAll()

    runDemo: () =>
      @timeLeft = 0
      @demo_i = 0

      model = getSearchParam('model')
      if model?
        cost = model.split('-')[1].replace('cost', '')
        @prompt.html markdown """
          <h3>Watching optimal model with cost = #{cost}</h3>
          <p>Press <code>space</code> to step through the model's actions.
        """
        @lowerMessage.html """
        <br>
        <p><button class='btn btn-primary centered' id='dashboard-return'>Try Another Cost</button>
        """
        $('#dashboard-return').click =>
          window.history.pushState("", "", "/" + location.search.split('&model')[0])
          @stage.empty()
          runDemo()
          return
      else
        wid = getSearchParam('participant')

        @prompt.html markdown """
          <h3>Watching participant #{wid}</h3>
          <p>Press <code>space</code> to step through the participant's actions. 
          Predictions of the optimal model fit to this participant are shown in blue.
          A prediction to stop planning is indicating by highlighting the initial node.
        """

        @lowerMessage.html """
        <br>
        <p><button class='btn btn-primary centered' id='dashboard-return'>Watch Someone Else</button>
        """
        $('#dashboard-return').click =>
          window.history.pushState("", "", "/" + location.search.split('&participant')[0])
          @stage.empty()
          runDemo()
          return

      for c in @demo.clicks
        unless model?
          @showPredictions()
        await sleep 100
        await waitKey()
        @clickState @states[c], String(c)
        @canvas.renderAll()
        @demo_i += 1

      unless model?
        @showPredictions()
      await waitKey()
      for s1 in @demo.path
        @move s, null, s1
        await sleep 600
        s = s1

    renderFrontier: =>
      if @moved
        return
      for s of _.keys @states
        @states[s].circle.setShadow
          blur: if @frontier.has s then 30 else 0
          color: '#FFDD47'
      @canvas.renderAll()

    hideFrontier: =>
      for s of _.keys @states
        @states[s].circle.setShadow
          blur: 0
          color: '#FFDD47'
      @canvas.renderAll()

    expandFrontier: (s) =>
      unless @stateDisplay is 'click'
        return
      @frontier.delete s

      if @expandOnly
        for action, [r, s1] of @graph[s]
          @frontier.add s1

      @renderFrontier()

      

    startTimer: =>
      @timeLeft = @minTime
      @waitMessage.html "Please wait #{@timeLeft} seconds"
      interval = ifvisible.onEvery 1, =>
        if @freeze then return
        @timeLeft -= 1
        @waitMessage.html "Please wait #{@timeLeft} seconds"
        # $('#mdp-time').html @timeLeft
        # $('#mdp-time').css 'color', (redGreen (-@timeLeft + .1))  # red if > 0
        if @timeLeft is 0
          do interval.stop
          do @checkFinished
      
      $('#mdp-time').html @timeLeft
      $('#mdp-time').css 'color', (redGreen (-@timeLeft + .1))

    endBlock: () ->
      @blockOver = true
      jsPsych.pluginAPI.cancelAllKeyboardResponses()
      @keyListener = jsPsych.pluginAPI.getKeyboardResponse
        valid_responses: ['space']
        rt_method: 'date'
        persist: false
        allow_held_key: false
        callback_function: (info) =>
          jsPsych.finishTrial @data
          do @display.empty
          do jsPsych.endCurrentTimeline

    # ---------- Responding to user input ---------- #

    # Called when a valid action is initiated via a key press.
    handleKey: (s0, a) =>
      LOG_DEBUG 'handleKey', s0, a
      if a is 'simulate'
        if @simulationMode
          @endSimulationMode()
        else
          @startSimulationMode()
      else
        if not @simulationMode
          @allowSimulation = false
          if @defaultLowerMessage
            @lowerMessage.html 'Move with the arrow keys.'
            @lowerMessage.css 'color', '#000'


        @data.actions.push a
        @data.simulationMode.push @simulationMode
        @data.actionTimes.push (Date.now() - @initTime)

        [_, s1] = @graph[s0][a]
        # LOG_DEBUG "#{s0}, #{a} -> #{r}, #{s1}"
        @move s0, a, s1

    startSimulationMode: () =>
      @simulationMode = true
      @player.set('top', @states[@initial].top - 20).set('left', @states[@initial].left)
      @player.set('opacity', 0.4)
      @canvas.renderAll()
      @arrive @initial
      # @centerMessage.html 'Ghost Score: <span id=mouselab-ghost-score/>'
      @rightMessage.html 'Ghost Score: <span id=mouselab-score/>'
      @resetScore()
      @drawScore @data.score
      @lowerMessage.html """
      <b>👻 Ghost Mode 👻</b>
      <br>
      Press <code>space</code> to return to your corporeal form.
      """
    
    endSimulationMode: () =>
      @simulationMode = false
      @player.set('top', @states[@initial].top).set('left', @states[@initial].left)
      @player.set('opacity', 1)
      @canvas.renderAll()
      @arrive @initial
      @centerMessage.html ''
      @rightMessage.html RIGHT_MESSAGE
      @resetScore()
      @lowerMessage.html @defaultLowerMessage

    getOutcome: (s0, a) =>
      LOG_DEBUG "getOutcome #{s0}, #{a}"
      [s1, r] = @graph[s0][a]
      if @stateRewards?
        r = @stateRewards[s1]
      return [r, s1]

    getReward: (s0, a, s1) =>
      if @stateRewards?
        @stateRewards[s1]
      else
        @graph[s0][a]

    move: (s0, a, s1) =>
      if @freeze
        LOG_INFO 'freeze!'
        @arrive s0, 'repeat'
        return

      nClick = @data.queries.click.state.target.length
      notEnoughClicks = (@special.startsWith 'trainClick') and nClick < @minClicks
      if notEnoughClicks
        @lowerMessage.html "<b>For these practice rounds, try inspecting at least #{@minClicks} nodes before moving</b>"
        @lowerMessage.css 'color', '#FC4754'
        @special = 'trainClickBlock'
        @arrive s0, 'repeat'
        return

      @moved = true
      for s, o of @states
        o.circle.setShadow
          blur: 0

      r = @getReward s0, a, s1
      LOG_DEBUG "move #{s0}, #{s1}, #{r}"
      s1g = @states[s1]
      @freeze = true
      
      newTop = if @simulationMode then s1g.top - 20 else s1g.top + TOP_ADJUST
      @player.animate {left: s1g.left, top: newTop},
        duration: @moveDelay
        onChange: @canvas.renderAll.bind(@canvas)
        onComplete: =>
          @data.rewards.push r
          @addScore r
          @spendEnergy @moveEnergy
          @arrive s1

    resetLowerMessage: () =>
      if @resetTimeout?
        clearTimeout @resetTimeout
      @resetTimeout = delay 3000, =>
        @lowerMessage.html @defaultLowerMessage
        @lowerMessage.css 'color', 'black'

    clickState: (g, s) =>
      LOG_DEBUG "clickState #{s}"
      if @exampleOnly
        return
      if @comprehension
        if @examplesLeft >= 0
          return
        @clickedNodes[s] = not @clickedNodes[s]
        g.setLabel (if @clickedNodes[s] then 'X' else '')
        
      unless @stateDisplay is 'click'
        return

      if g.label.text
        # already clicked
        return
        
      if @moved
        @lowerMessage.html "<b>You can't use the node inspector after moving!</b>"
        @lowerMessage.css 'color', '#FC4754'
        @resetLowerMessage()
        return

      if @delaying
        @lowerMessage.html "<b>The node inspector is recharging!</b>"
        @lowerMessage.css 'color', '#FC4754'
        @resetLowerMessage()
        return
      
      if @expandOnly and not @frontier.has(s)
        @lowerMessage.html "<b>You can only inspect the highlighted nodes!</b>"
        @lowerMessage.css 'color', '#FC4754'
        @resetLowerMessage()
        return
              
      if @complete or ("#{s}" is "#{@initial}") or @freeze
        return

      if @data.queries.click.state.target.length == (@minClicks - 1)
        if @special is 'trainClick'
          @lowerMessage.html "Continue inspecting nodes or move with the arrow keys."
        else if @special is 'trainClickBlock'
          @lowerMessage.html '<b>Nice job! You can click on more nodes or start moving.</b>'
          @lowerMessage.css 'color', '#000'
      
      if @special is 'trainClickBlock' and @data.queries.click.state.target.length == (@minClicks - 1)
        @lowerMessage.html '<b>Nice job! You can click on more nodes or start moving.</b>'
        @lowerMessage.css 'color', '#000'


      if @stateLabels and @stateDisplay is 'click' and not g.label.text
        @addScore -@stateClickCost
        @recordQuery 'click', 'state', s
        @spendEnergy @clickEnergy
        g.setLabel @stateLabels[s]

        if @clickDelay
          @delaying = true
          @hideFrontier()          
          delay @clickDelay, =>
            @delaying = false
            @expandFrontier s
        else
          @expandFrontier s

    mouseoverState: (g, s) =>
      # LOG_DEBUG "mouseoverState #{s}"
      if @stateLabels and @stateDisplay is 'hover'
        # webppl.run('flip()', (s, x) -> g.setLabel (Number x))
        g.setLabel @stateLabels[s]
        @recordQuery 'mouseover', 'state', s

    mouseoutState: (g, s) =>
      # LOG_DEBUG "mouseoutState #{s}"
      if @stateLabels and @stateDisplay is 'hover'
        g.setLabel ''
        @recordQuery 'mouseout', 'state', s

    clickEdge: (g, s0, r, s1) =>
      if not @complete and g.label.text is '?'
        LOG_DEBUG "clickEdge #{s0} #{r} #{s1}"
        if @edgeLabels and @edgeDisplay is 'click' and g.label.text in ['?', '']
          g.setLabel @getEdgeLabel s0, r, s1
          @recordQuery 'click', 'edge', "#{s0}__#{s1}"

    mouseoverEdge: (g, s0, r, s1) =>
      # LOG_DEBUG "mouseoverEdge #{s0} #{r} #{s1}"
      if @edgeLabels and @edgeDisplay is 'hover'
        g.setLabel @getEdgeLabel s0, r, s1
        @recordQuery 'mouseover', 'edge', "#{s0}__#{s1}"

    mouseoutEdge: (g, s0, r, s1) =>
      # LOG_DEBUG "mouseoutEdge #{s0} #{r} #{s1}"
      if @edgeLabels and @edgeDisplay is 'hover'
        g.setLabel ''
        @recordQuery 'mouseout', 'edge', "#{s0}__#{s1}"

    getEdgeLabel: (s0, r, s1) =>
      if @edgeLabels is 'reward'
        '®'
      else
        @edgeLabels["#{s0}__#{s1}"]

    recordQuery: (queryType, targetType, target) =>
      @canvas.renderAll()
      # LOG_DEBUG "recordQuery #{queryType} #{targetType} #{target}"
      # @data["#{queryType}_#{targetType}_#{target}"]
      @data.queries[queryType][targetType].target.push target
      @data.queries[queryType][targetType].time.push Date.now() - @initTime


    # ---------- Updating state ---------- #

    # Called when the player arrives in a new state.
    arrive: (s, repeat=false) ->
      if @exampleOnly
        @examplesLeft = @examples.length
        @showExample()
        return

      if @comprehension
        return
      g = @states[s]
      g.setLabel @stateRewards[s]
      @canvas.renderAll()
      @freeze = false
      LOG_DEBUG 'arrive', s

      unless repeat  # sending back to previous state
        @data.path.push s

      # Get available actions.
      if @graph[s]
        keys = (@keys[a] for a in (Object.keys @graph[s]))
      else
        keys = []
      if @allowSimulation
        keys.push 'space'
      if not keys.length
        @complete = true
        @checkFinished()
        return

      unless mdp.demo
        # Start key listener.
        @keyListener = jsPsych.pluginAPI.getKeyboardResponse
          valid_responses: keys
          rt_method: 'date'
          persist: false
          allow_held_key: false
          callback_function: (info) =>
            action = @invKeys[info.key]
            LOG_DEBUG 'key', info.key
            @data.rt.push info.rt
            @handleKey s, action

    addScore: (v) =>
      @data.score += v
      if @simulationMode
        score = @data.score
      else
        SCORE += v
        score = SCORE
      @drawScore(score)

    resetScore: =>
      @data.score = 0
      @drawScore SCORE

    drawScore: (score)=>
      $('#mouselab-score').html ('$' + score)
      $('#mouselab-score').css 'color', redGreen score

    spendEnergy: (v) =>
      @_block.energyLeft -= v
      if @_block.energyLeft <= 0
        LOG_INFO 'OUT OF ENERGY'
        @_block.energyLeft = 0
        @freeze = true
        @lowerMessage.html """<b>You're out of energy! Press</b> <code>space</code> <b>to continue.</br>"""
        @endBlock()
      $('#mouselab-energy').html @_block.energyLeft
      # $('#mouselab-').css 'color', redGreen SCORE

          


    # ---------- Starting the trial ---------- #

    run: =>
      jsPsych.pluginAPI.cancelAllKeyboardResponses()
      LOG_DEBUG 'run'
      @buildMap()
  
      if @expandOnly
        @frontier =  new Set()
      else
        @frontier = new Set(_.keys(mdp.states))

      if @timeLimit or @minTime
        do @startTimer
      @expandFrontier @initial
      fabric.Image.fromURL @playerImage, ((img) =>
        @initPlayer img
        @canvas.renderAll()
        @initTime = Date.now()
        @arrive @initial
      )
      if @demo?
        @runDemo()
    # Draw object on the canvas.
    draw: (obj) =>
      @canvas.add obj
      return obj


    # Draws the player image.
    initPlayer: (img) =>
      LOG_DEBUG 'initPlayer'
      top = @states[@initial].top + TOP_ADJUST
      left = @states[@initial].left
      img.scale(0.25)
      img.set('top', top).set('left', left)
      @draw img
      @player = img

    # Constructs the visual display.
    buildMap: =>
      # Resize canvas.
      [xs, ys] = _.unzip (_.values @layout)
      minx = _.min xs
      miny = _.min ys
      maxx = _.max xs
      maxy = _.max ys
      [width, height] = [maxx - minx + 1, maxy - miny + 1]

      @canvasElement.attr(width: width * SIZE, height: height * SIZE)
      @canvas = new fabric.Canvas 'mouselab-canvas', selection: false
      @canvas.defaultCursor = 'pointer'

      @states = {}
      for s, location of (removePrivate @layout)
        [x, y] = location

        @states[String(s)] = new State s, x - minx, y - miny,
          fill: '#bbb'
          label: if @stateDisplay is 'always' then @stateLabels[s] else ''
          # label: s

      for s0, actions of (removePrivate @graph)
        for a, [r, s1] of actions
          new Edge @states[s0], r, @states[s1],
            label: if @edgeDisplay is 'always' then @getEdgeLabel s0, r, s1 else ''


    # ---------- ENDING THE TRIAL ---------- #

    # Creates a button allowing user to move to the next trial.
    finishTrial:  =>
      @data.trialTime = getTime() - @initTime
      jsPsych.finishTrial @data
      do @stage.empty

    endTrial: =>
      window.clearInterval @timerID
      if @blockOver
        return
      @lowerMessage.html """
        You made <span class=mouselab-score/> on this round.
        <br>
        <b>Press</b> <code>space</code> <b>to continue.</b>
      """
      $('.mouselab-score').html '$' + @data.score
      $('.mouselab-score').css 'color', redGreen @data.score
      $('.mouselab-score').css 'font-weight', 'bold'
      @keyListener = jsPsych.pluginAPI.getKeyboardResponse
        valid_responses: ['space']
        rt_method: 'date'
        persist: false
        allow_held_key: false
        callback_function: @finishTrial

    checkFinished: =>
      if @complete
        if @timeLeft?
          if @timeLeft > 0
            @waitMessage.show()
          else
            @waitMessage.hide()
            do @endTrial
        else
          do @endTrial


  #  =========================== #
  #  ========= Graphics ========= #
  #  =========================== #

  class State
    constructor: (@name, left, top, config={}) ->
      left = (left + 0.5) * SIZE
      top = (top + 0.5) * SIZE
      conf =
        left: left
        top: top
        fill: STATE_COLOR
        radius: SIZE / 4
        label: ''
      _.extend conf, config

      # Due to a quirk in Fabric, the maximum width of the label
      # is set when the object is initialized (the call to super).
      # Thus, we must initialize the label with a placeholder, then
      # set it to the proper value afterwards.
      @circle = new fabric.Circle conf
      FOO = @circle
      @label = new Text '----------', left, top,
        fontSize: SIZE / 4
        fill: '#44d'

      @radius = @circle.radius
      @left = @circle.left
      @top = @circle.top

      mdp.canvas.add(@circle)
      mdp.canvas.add(@label)
      
      @setLabel conf.label
      # @setLabel @name
      unless mdp.demo?
        @circle.on('mousedown', => mdp.clickState this, @name)
        @label.on('mousedown', => mdp.clickState this, @name)
        @circle.on('mouseover', => mdp.mouseoverState this, @name)
        @circle.on('mouseout', => mdp.mouseoutState this, @name)

    setLabel: (txt, conf={}) ->
      LOG_DEBUG 'setLabel', txt
      {
        pre=''
        post=''
      } = conf
      # LOG_DEBUG "setLabel #{txt}"
      if txt?
        @label.setText "#{pre}#{txt}#{post}"
        @label.setFill (redGreen txt)
      else
        @label.setText ''
      @dirty = true


  class Edge
    constructor: (c1, reward, c2, config={}) ->
      {
        spacing=8
        adjX=0
        adjY=0
        rotateLabel=false
        label=''
      } = config

      [x1, y1, x2, y2] = [c1.left + adjX, c1.top + adjY, c2.left + adjX, c2.top + adjY]

      @arrow = new Arrow(x1, y1, x2, y2,
                         c1.radius + spacing, c2.radius + spacing)

      ang = (@arrow.ang + Math.PI / 2) % (Math.PI * 2)
      if 0.5 * Math.PI <= ang <= 1.5 * Math.PI
        ang += Math.PI
      [labX, labY] = polarMove(x1, y1, angle(x1, y1, x2, y2), SIZE * 0.45)

      # See note about placeholder in State.
      @label = new Text '----------', labX, labY,
        angle: if rotateLabel then (ang * 180 / Math.PI) else 0
        fill: redGreen label
        fontSize: SIZE / 4
        textBackgroundColor: 'white'

      @arrow.on('mousedown', => mdp.clickEdge this, c1.name, reward, c2.name)
      @arrow.on('mouseover', => mdp.mouseoverEdge this, c1.name, reward, c2.name)
      @arrow.on('mouseout', => mdp.mouseoutEdge this, c1.name, reward, c2.name)
      @setLabel label

      mdp.canvas.add(@arrow)
      mdp.canvas.add(@label)

    setLabel: (txt, conf={}) ->
      {
        pre=''
        post=''
      } = conf
      # LOG_DEBUG "setLabel #{txt}"
      if txt
        @label.setText "#{pre}#{txt}#{post}"
        @label.setFill (redGreen txt)
      else
        @label.setText ''
      @dirty = true
      


  class Arrow extends fabric.Group
    constructor: (x1, y1, x2, y2, adj1=0, adj2=0) ->
      ang = (angle x1, y1, x2, y2)
      [x1, y1] = polarMove(x1, y1, ang, adj1)
      [x2, y2] = polarMove(x2, y2, ang, - (adj2+7.5))

      line = new fabric.Line [x1, y1, x2, y2],
        stroke: '#555'
        selectable: false
        strokeWidth: 3

      centerX = (x1 + x2) / 2
      centerY = (y1 + y2) / 2
      deltaX = line.left - centerX
      deltaY = line.top - centerY
      dx = x2 - x1
      dy = y2 - y1

      point = new (fabric.Triangle)(
        left: x2 + deltaX
        top: y2 + deltaY
        pointType: 'arrow_start'
        angle: ang * 180 / Math.PI
        width: 10
        height: 10
        fill: '#555')

      super [line, point]
      @ang = ang
      @centerX = centerX
      @centerY = centerY



  class Text extends fabric.Text
    constructor: (txt, left, top, config) ->
      txt = String(txt)
      conf =
        left: left
        top: top
        fontFamily: 'helvetica'
        fontSize: SIZE / 8

      _.extend conf, config
      super txt, conf


  # ================================= #
  # ========= jsPsych stuff ========= #
  # ================================= #
  
  plugin =
    trial: (display_element, trialConfig) ->
      trialConfig.callback?()

      # trialConfig = jsPsych.pluginAPI.evaluateFunctionParameters trialConfig, ['_init', 'constructor']
      trialConfig.display = display_element

      LOG_INFO 'trialConfig', trialConfig

      trial = new MouselabMDP trialConfig
      trial.run()
      if trialConfig._block
        trialConfig._block.trialCount += 1
      TRIAL_INDEX += 1

  return plugin

# ---
# generated by js2coffee 2.2.0