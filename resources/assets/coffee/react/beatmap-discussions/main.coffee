###
# Copyright 2015 ppy Pty. Ltd.
#
# This file is part of osu!web. osu!web is distributed with the hope of
# attracting more community contributions to the core ecosystem of osu!.
#
# osu!web is free software: you can redistribute it and/or modify
# it under the terms of the Affero GNU General Public License version 3
# as published by the Free Software Foundation.
#
# osu!web is distributed WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with osu!web.  If not, see <http://www.gnu.org/licenses/>.
###
{a, div, h1, p} = React.DOM
el = React.createElement

modeSwitcher = document.getElementsByClassName('js-mode-switcher')

BeatmapDiscussions.Main = React.createClass
  mixins: [React.addons.PureRenderMixin]


  getInitialState: ->
    beatmaps = BeatmapHelper.group @props.initial.beatmapset.beatmaps

    beatmapset: @props.initial.beatmapset
    beatmaps: beatmaps
    beatmapsetDiscussion: @props.initial.beatmapsetDiscussion
    currentBeatmap: BeatmapHelper.default(group: beatmaps)
    currentUser: currentUser
    userPermissions: @props.initial.userPermissions
    mode: 'timeline'
    readPostIds: _.chain(@props.initial.beatmapsetDiscussion.beatmap_discussions)
      .map (d) =>
        d.beatmap_discussion_posts.map (r) =>
          r.id
      .flatten()
      .value()
    currentFilter: 'total'


  componentDidMount: ->
    $.subscribe 'beatmap:select.beatmapDiscussions', @setCurrentBeatmapId
    $.subscribe 'beatmapset:mode:set.beatmapDiscussions', @setCurrentPlaymode
    $.subscribe 'beatmapsetDiscussion:update.beatmapDiscussions', @setBeatmapsetDiscussion
    $.subscribe 'beatmapset:update.beatmapDiscussions', @setBeatmapset
    $.subscribe 'beatmapDiscussion:jump.beatmapDiscussions', @jumpTo
    $.subscribe 'beatmapDiscussion:setMode.beatmapDiscussions', @setMode
    $.subscribe 'beatmapDiscussionPost:markRead.beatmapDiscussions', @markPostRead
    $.subscribe 'beatmapDiscussion:filter.beatmapDiscussions', @setFilter

    @jumpByHash()

    @checkNewTimeout = Timeout.set @checkNewTimeoutDefault, @checkNew


  componentWillUnmount: ->
    $.unsubscribe '.beatmapDiscussions'

    Timeout.clear @checkNewTimeout
    @checkNewAjax?.abort?()


  componentWillUpdate: ->
    @indexedUsers = null


  render: ->
    div null,
      el BeatmapDiscussions.Header,
        beatmapset: @state.beatmapset
        beatmaps: @state.beatmaps
        currentBeatmap: @state.currentBeatmap
        currentUser: @state.currentUser
        currentFilter: @state.currentFilter
        beatmapsetDiscussion: @state.beatmapsetDiscussion
        lookupUser: @lookupUser

      el BeatmapDiscussions.ModeSwitcher,
        mode: @state.mode

      div
        className: 'osu-layout__section osu-layout__section--extra'
        el BeatmapDiscussions.NewDiscussion,
          currentUser: @state.currentUser
          currentBeatmap: @state.currentBeatmap
          mode: @state.mode

        el BeatmapDiscussions.Discussions,
          beatmapset: @state.beatmapset
          currentBeatmap: @state.currentBeatmap
          currentUser: @state.currentUser
          beatmapsetDiscussion: @state.beatmapsetDiscussion
          lookupUser: @lookupUser
          userPermissions: @state.userPermissions
          mode: @state.mode
          readPostIds: @state.readPostIds
          currentFilter: @state.currentFilter


  setBeatmapsetDiscussion: (_e, {beatmapsetDiscussion, callback}) ->
    @setState
      beatmapsetDiscussion: beatmapsetDiscussion
      callback

  setBeatmapset: (_e, {beatmapset, callback}) ->
    @setState
      beatmapset: beatmapset
      beatmaps: BeatmapHelper.group beatmapset.beatmaps
      callback

  setCurrentBeatmapId: (_e, {id, callback}) ->
    return callback?() if !id?

    osu.setHash "#:#{id}"

    return callback?() if id == @state.currentBeatmap.id

    beatmap = @state.beatmapset.beatmaps.find (bm) =>
      bm.id == id

    return callback?() if !beatmap?

    @setState currentBeatmap: beatmap, callback


  setCurrentPlaymode: (_e, {mode}) ->
    beatmap = BeatmapHelper.default items: @state.beatmaps[mode]
    @setCurrentBeatmapId null, id: beatmap?.id


  lookupUser: (id) ->
    @indexedUsers ?= _.keyBy @state.beatmapsetDiscussion.users, 'id'

    @indexedUsers[id]


  jumpTo: (_e, {id}) ->
    discussion = @state.beatmapsetDiscussion.beatmap_discussions.find (d) => d.id == id

    return if !discussion?

    mode = if discussion.timestamp? then 'timeline' else 'general'

    @setMode null, mode, =>
      @setCurrentBeatmapId null,
        id: discussion.beatmap_id
        callback: =>
          $.publish 'beatmapDiscussionEntry:highlight', id: discussion.id

          target = $(".js-beatmap-discussion-jump[data-id='#{id}']")
          $(window).stop().scrollTo target, 500,
            offset: modeSwitcher[0].getBoundingClientRect().height * -1


  setMode: (_e, mode, callback) ->
    return callback?() if mode == @state.mode

    @setState mode: mode, callback


  jumpByHash: ->
    jumpId = document.location.hash.match(/\/(\d+)/)?[1]

    if jumpId?
      return $.publish 'beatmapDiscussion:jump', id: parseInt(jumpId, 10)

    beatmapId = document.location.hash.match(/:(\d+)/)?[1]
    beatmapId ?= @state.currentBeatmap.id
    $.publish 'beatmap:select', id: parseInt(beatmapId, 10)


  checkNewTimeoutDefault: 10000
  checkNewTimeoutMax: 60000

  checkNew: ->
    @nextTimeout ?= @checkNewTimeoutDefault

    Timeout.clear @checkNewTimeout

    @checkNewAjax = $.ajax document.location.pathname,
      data:
        format: 'json'
        last_updated: moment(@state.beatmapsetDiscussion.updated_at).unix()

    .done (data) =>
      if data.updated? && !data.updated
        @nextTimeout *= 2
        return

      @nextTimeout = @checkNewTimeoutDefault

      @setBeatmapsetDiscussion null, beatmapsetDiscussion: data.beatmapsetDiscussion

    .always =>
      @nextTimeout = Math.min @nextTimeout, @checkNewTimeoutMax

      @checkNewTimeout = Timeout.set @nextTimeout, @checkNew


  markPostRead: (_e, {id}) ->
    return if _.includes @state.readPostIds, id

    @setState readPostIds: @state.readPostIds.concat(id)


  setFilter: (_e, {filter}) ->
    return if filter == @state.currentFilter

    @setState currentFilter: filter
