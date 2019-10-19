# Ultimately this class should just wrap the calendar plugin and serve events.
# Most other heavy lifting should be done by other classes like CalendarLinkManager.
Gather.Views.ReservationCalendarView = Backbone.View.extend

  URL_PARAMS_TO_VIEW_TYPES:
    'day': 'agendaDay'
    'week': 'agendaWeek'
    'month': 'month'

  initialize: (options) ->
    @newUrl = options.newUrl
    @calendar = @$('#calendar')
    @ruleSet = options.ruleSet
    @resourceId = options.resourceId
    @savedSettings = @loadSettings()
    @showAppropriateEarlyLink()

    @calendar.fullCalendar
      events: options.feedUrl
      defaultView: @initialViewType(options.viewType, options.defaultViewType)
      defaultDate: options.focusDate || @savedSettings.currentDate
      height: 'auto'
      minTime: @minTime()
      allDaySlot: false
      eventOverlap: false
      selectable: @ruleSet.access_level != "read_only"
      selectOverlap: false
      selectHelper: true
      longPressDelay: 500
      header:
        left: 'title'
        center: 'agendaDay,agendaWeek,month'
        right: 'today prev,next'
      select: @onSelect.bind(this)
      windowResize: @onWindowResize.bind(this)
      viewRender: @onViewRender.bind(this)
      loading: @onLoading.bind(this)
      eventDrop: @onEventChange.bind(this)
      eventResize: @onEventChange.bind(this)

  events:
    'click .modal .btn-primary': 'create'
    'click .early': 'showHideEarly'

  onSelect: (start, end, _, view) ->
    modal = @$('#create-confirm-modal')
    body = modal.find('.modal-body')
    changedInterval = false

    # If month view, default selection is 12am to 12am, which is weird.
    # Change to 12:00 - 13:00 instead. This works better with fixed times.
    # We need to do this before applying fixed times so that overnight stays go from the day clicked
    # to the next day instead of ending on the day clicked.
    if view.name == "month" && start.hours() == 0 && end.hours() == 0
      start.hours(12)
      end.hours(13)
      end.days(end.days() - 1)

    [start, end, changed] = @applyFixedTimes(start, end)

    # Redraw selection if fixed times applied. But doing this in month mode causes an infinite loop
    # and doesn't provide any useful feedback to the user.
    if changed && view.name != "month"
      @calendar.fullCalendar('select', start, end)
      return

    # If there is an overlap we halt the process because overlaps aren't allowed.
    if @hasEventInInterval(start, end)
      @calendar.fullCalendar('unselect')
      return

    # Save for create method to use.
    @selection =
      start: start.format(Gather.TIME_FORMATS.machineDatetime)
      end: end.format(Gather.TIME_FORMATS.machineDatetime)

    # Build confirmation string
    if (start.format('YYYYMMDD') == end.format('YYYYMMDD'))
      date = start.format(Gather.TIME_FORMATS.regDate)
      startTime = start.format(Gather.TIME_FORMATS.regTime)
      endTime = end.format(Gather.TIME_FORMATS.regTime)
      body.html("Reserve on <b>#{date}</b> from <b>#{startTime}</b> to <b>#{endTime}</b>?")
    else
      startTime = start.format(Gather.TIME_FORMATS.fullDatetime)
      endTime = end.format(Gather.TIME_FORMATS.fullDatetime)
      body.html("Reserve from <b>#{startTime}</b> to <b>#{endTime}</b>?")

    modal.modal('show')

  onWindowResize: ->
    @setViewForWidth()

  onViewRender: ->
    @trigger('viewRender')
    @saveSettings()

  onLoading: (isLoading) ->
    Gather.loadingIndicator[if isLoading then 'show' else 'hide']()

  onEventChange: (event, _, revertFunc) ->
    $.ajax
      url: "/reservations/#{event.id}"
      method: "POST"
      data:
        _method: "PATCH"
        reservations_reservation:
          starts_at: event.start.format()
          ends_at: event.end.format()
      error: (xhr) ->
        revertFunc()
        Gather.errorModal.modal('show').find('.modal-body').html(xhr.responseText)

  setViewForWidth: ->
    @calendar.fullCalendar('changeView', 'agendaDay') if @forceDay()

  forceDay: ->
    $(window).width() < 640

  create: ->
    # newUrl includes a QS param already so we use '&'
    window.location.href = "#{@newUrl}&#{$.param(@selection)}"

  initialViewType: (linkParam, defaultType) ->
    type = @forceDay() && 'day' || linkParam || @savedSettings.viewType || defaultType || 'week'
    @URL_PARAMS_TO_VIEW_TYPES[type]

  minTime: ->
    if @savedSettings.earlyMorning then '00:00:00' else '06:00:00'

  viewType: ->
    @calendar.fullCalendar('getView').name.replace('agenda', '').toLowerCase()

  currentDate: ->
    @calendar.fullCalendar('getView').intervalStart.format(Gather.TIME_FORMATS.compactDate)

  hasEventInInterval: (start, end) ->
    matches = @calendar.fullCalendar 'clientEvents', (event) ->
      event.start.isBefore(end) && event.end.isAfter(start)
    matches.length > 0

  applyFixedTimes: (start, end) ->
    fixedStart = @ruleSet.fixed_start_time && $.fullCalendar.moment(@ruleSet.fixed_start_time)
    fixedEnd = @ruleSet.fixed_end_time && $.fullCalendar.moment(@ruleSet.fixed_end_time)
    changed = false

    if fixedStart && fixedStart.format('HHmm') != start.format('HHmm')
      start = @nearestFixedTime(start, fixedStart)
      length = end.diff(start)
      end = $.fullCalendar.moment(start).add(length)
      changed = true

    if fixedEnd && fixedEnd.format('HHmm') != end.format('HHmm')
      end = @nearestFixedTime(end, fixedEnd)
      changed = true

    end.add(1, 'day') if end.isBefore(start)

    [start, end, changed]

  # Gets the moment nearest to selectedTime with the hours and minutes of fixedTime.
  nearestFixedTime: (selectedTime, fixedTime) ->
    today = $.fullCalendar.moment(selectedTime)
    today.hours(fixedTime.hours()).minutes(fixedTime.minutes())

    if selectedTime.isBefore(today)
      nearest = $.fullCalendar.moment(today).subtract(1, 'day')
    else
      nearest = today

    nearest.add(1, 'days') if selectedTime.diff(nearest, 'hours', true) > 12

    nearest

  # Toggles the earlyMorning setting and re-renders.
  showHideEarly: (e) ->
    e.preventDefault()
    @savedSettings.earlyMorning = !@savedSettings.earlyMorning
    @showAppropriateEarlyLink()
    @calendar.fullCalendar('option', 'minTime', @minTime())

  showAppropriateEarlyLink: ->
    @$('#hide-early').css(display: if @savedSettings.earlyMorning then 'inline' else 'none')
    @$('#show-early').css(display: if @savedSettings.earlyMorning then 'none' else 'inline')

  storageKey: ->
    "calendar#{@resourceId}Settings"

  loadSettings: ->
    settings = JSON.parse(window.localStorage.getItem(@storageKey()) || '{}')
    @expireCurrentDateSettingAfterOneHour(settings)
    settings

  expireCurrentDateSettingAfterOneHour: (settings) ->
    if settings.savedAt
      settingsAge = moment.duration(moment().diff(moment(settings.savedAt))).asSeconds()
      delete settings.currentDate if settingsAge > 3600

  saveSettings: ->
    @savedSettings.savedAt = new Date()
    @savedSettings.viewType = @viewType()
    @savedSettings.currentDate = @currentDate()

    window.localStorage.setItem(@storageKey(), JSON.stringify(@savedSettings))
