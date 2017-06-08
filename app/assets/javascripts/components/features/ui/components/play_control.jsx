import { Link } from 'react-router';
import { FormattedMessage } from 'react-intl';
import PropTypes from 'prop-types';
import IconButton from '../../../components/icon_button';
import api from '../../../api';
import YouTubePlayer from 'youtube-player';
import createStream from '../../../../components/stream';

class MusicPlayer extends React.PureComponent {

  constructor (props, context) {
    super(props, context);
    this.state = {
      isOpen: false,
      isPlaying: false,
      targetDeck: 1,
      deck: undefined,
      player: undefined,
      offset_time: 0,
      offset_start_time: 0,
      offset_counter: undefined
    };

    this.ytControl = undefined;
    this.audioRef = undefined;

    this.setURLRef = this.setURLRef.bind(this);
    this.setAudioRef = this.setAudioRef.bind(this);
    this.getDuration = this.getDuration.bind(this);
    this.getMockState = this.getMockState.bind(this);
    this.handleClickSkip = this.handleClickSkip.bind(this);
    this.handleClickDeck = this.handleClickDeck.bind(this);
    this.handleClickToggle = this.handleClickToggle.bind(this);
    this.handleClickOverlay = this.handleClickOverlay.bind(this);
    this.handleClickDeckTab = this.handleClickDeckTab.bind(this);
    this.getStartOffsetTime = this.getStartOffsetTime.bind(this);
    this.handleSubmitAddForm = this.handleSubmitAddForm.bind(this);

    this.fetchDeck(1);

    this.subscription = createStream('ws://localhost:4000/', this.props.accessToken, `playlist&deck=${this.state.targetDeck}`, {
      received: (data) => {
        switch(data.event) {

        case 'add':
          {
            const payload = data.payload;
            const deck = Object.assign({}, this.state.deck);
            deck.queues.push(payload);
            this.setState({deck});
          }
          break;
        case 'play':
          {
            const deck = Object.assign({}, this.state.deck);
            deck.queues.shift();
            if(this.ytControl){
              this.ytControl.stopVideo();
            }

            if(!deck || !("queues" in deck) || !(deck.queues.length) || deck.queues[0].source_type === 'youtube') {
              if(this.ytControl) this.ytControl.destroy();
              this.ytControl = undefined;
            }else{
              setTimeout(()=>{
                this.ytControl = YouTubePlayer('yt-player');
                this.ytControl.loadVideoById(deck.queues[0].source_id);
                this.ytControl.playVideo();

                if(this.state.isPlaying){
                  this.ytControl.mute();
                }else{
                  this.ytControl.unMute();
                }
              }, 0);
            }

            this.setState({
              deck,
              offset_start_time: (new Date().getTime()),
              offset_time: 0,
            });
          }
          break;
        case 'delete':
          {
            const payload = data.payload;
            const deck = Object.assign({},this.state.deck);
            deck.queues.push(payload);
            this.setState({
              deck
            });
          }
          break;
        }
      }
    });
  }

  fetchDeck(id) {
    return new Promise((resolve, reject)=>{
      api(this.getMockState).get(`/api/v1/playlists/${id}`)
      .then((response)=>{
        const interval = setInterval(()=>{
          this.setState({
            offset_time: parseInt(new Date().getTime()) - parseInt(this.state.offset_start_time)
          })
        },14);
        this.setState({
          deck: response.data.deck,
          offset_start_time: (new Date().getTime()) - (new Date(0).setSeconds(response.data.deck.time_offset)),
          offset_time: parseInt(response.data.deck.time_offset),
          offset_counter: interval
        })

        if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) || this.state.deck.queues[0].source_type === 'youtube') {
          if(this.ytControl) this.ytControl.destroy();
          this.ytControl = undefined;
          return resolve();
        }
        setTimeout(()=>{
          this.ytControl = YouTubePlayer('yt-player');
          this.ytControl.loadVideoById(this.state.deck.queues[0].source_id);
          this.ytControl.playVideo();

          if(!this.state.isPlaying) {
            this.ytControl.mute()
          } else {
            this.ytControl.unMute();
          }
        },0);
      })
      .catch((err)=>{
        return reject(err);
      })
    });
  }

  handleClickDeck () {
    this.setState({isOpen: true});
  }

  handleClickOverlay () {
    this.setState({isOpen: false});
  }

  handleClickDeckTab (index) {
    if(index === this.state.targetDeck) return;
    this.setState({targetDeck: index});
    this.fetchDeck(index);
  }

  handleSubmitAddForm (e) {
    e.preventDefault();
    return new Promise((resolve, reject)=>{
      api(this.getMockState).post(`/api/v1/playlists/${this.state.targetDeck}/deck_queues`, {link: this.urlRef.value})
      .then((response)=>{
        this.urlRef.value = "";
      })
      .catch((err)=>{
        return reject(err);
      })
    });
  }

  handleClickToggle () {
    if(this.ytControl) {
      if(this.state.isPlaying) {
        this.ytControl.mute();
      }else{
        this.ytControl.unMute();
      }
    }
    this.setState({isPlaying: (!this.state.isPlaying)});
  }

  handleClickSkip () {
    api(this.getMockState).delete(`/api/v1/playlists/${this.state.targetDeck}/deck_queues/${this.state.deck.queues[0].id}`)
    .then((response)=>{
    })
    .catch((err)=>{
      return err;
    })
  }

  setURLRef (c) {
    this.urlRef = c;
  }

  getMockState () {
    return {
      getIn: () => this.props.accessToken
    }
  }

  getStartOffsetTime () {
    if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) ) return 0;
    return !this.state.offset_time ? 0 : parseInt(this.state.offset_time / 1000);
  }

  getDuration () {
    if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) ) return 0;
    return this.state.deck.queues[0].duration;
  }

  setAudioRef (c) {
    this.audioRef = c;
    if(this.audioRef) this.audioRef.volume = 0.1;
  }

  render () {
    const playerClass = `player-control${this.state.isOpen ? ' is-open':''}`;
    const iconClass = `fa fa-volume-${this.state.isPlaying?'up':'off'}`;
    const toggleClass = `control-bar__controller-toggle is-${this.state.isPlaying?'playing':'pause'}`;

    let playerSeekBarStyle = {};
    let nowPlayingArtwork = {};
    let ytplayerStyle = {};

    if(this.state.deck && ("queues" in this.state.deck) && this.state.deck.queues.length) {
      nowPlayingArtwork = {
        backgroundImage: `url(${this.state.deck.queues[0].thumbnail_url})`
      };
      ytplayerStyle = {
        display: this.state.deck.queues[0].source_type === 'youtube' ? 'block' : 'none'
      }
      playerSeekBarStyle = {
        width: `${(this.state.offset_time / (this.state.deck.queues[0].duration*1000) )*100}%`
      }
    }

    return (
      <div className={playerClass}>
        <div className='player-control__control-bar'>
          <div className='control-bar__controller'>
            <div className={toggleClass} onClick={this.handleClickToggle}>
              <i className={iconClass} />
            </div>
            <div className='control-bar__controller-skip' onClick={this.handleClickSkip}>
              SKIP
            </div>
            {(()=>{
              if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) ) return null;
              return (
                <div className='control-bar__controller-info'>
                  <span className='control-bar__controller-now'>{parseInt(Math.min(this.getStartOffsetTime(), this.getDuration())/60)}:{("0"+Math.min(this.getStartOffsetTime(), this.getDuration())%60).slice(-2)}</span>
                  <span className='control-bar__controller-separater'>/</span>
                  <span className='control-bar__controller-time'>{parseInt(this.getDuration()/60)}:{("0"+this.getDuration()%60).slice(-2)}</span>
                </div>
              );
            })()}
          </div>
          <div className='control-bar__deck' onClick={this.handleClickDeck}>
            <ul className='control-bar__deck-selector'>
              {(()=>[1,2,3].map(index=>(
                <li key={index} className={'deck-selector__selector-body'+(this.state.targetDeck === index ? ' active':'')} onClick={()=>this.handleClickDeckTab(index)}>
                  <img src="/player/pawoo-music-playlist-icon.svg" /><span>DECK{index}</span>
                </li>
              )))()}
            </ul>
            <div className="deck_queue-wrapper">
              <div className="queue-item__artwork" style={nowPlayingArtwork}>
                {(()=>{
                  if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) ) return null;

                  if(this.state.deck.queues[0].source_type === 'youtube'){
                    return (
                      <div className='queue-item__ytplayer' style={ytplayerStyle}>
                        <div id="yt-player" />
                      </div>
                    );
                  }

                  if(this.state.deck.queues[0].video_url){
                    return (
                      <video autoPlay style={nowPlayingArtwork} muted={!this.state.isPlaying}>
                        <source src={this.state.deck.queues[0].video_url}/>
                      </video>
                    );
                  }else{
                    return (
                      <audio ref={this.setAudioRef} autoPlay src={this.state.deck.queues[0].music_url} muted={!this.state.isPlaying} />
                    );
                  }
                })()}
              </div>
              <ul className="deck__queue">
                {(()=>{
                  if(!this.state.deck || !("queues" in this.state.deck) || !(this.state.deck.queues.length) ){
                    return (
                      <li className="deck__queue-item">
                        <div className="queue-item__main">
                          <div className='queue-item__metadata'>
                            プレイリストに曲がありません
                          </div>
                        </div>
                        <div className='queue-item__datasource' />
                      </li>
                    );
                  }

                  return this.state.deck.queues.map(queue_item=>(
                      <li key={queue_item.id} className="deck__queue-item">
                        <div className="queue-item__main">
                          <div className='queue-item__metadata'>
                            {queue_item.info}
                          </div>
                        </div>
                        <div className='queue-item__datasource'>
                          <a href={queue_item.link} target="_blank"><img src={(()=>`/player/logos/${queue_item.source_type}.svg`)()} /></a>
                        </div>
                      </li>
                    )
                  );
                })()}
                <li className="deck__queue-add-form">
                  <form onSubmit={this.handleSubmitAddForm}>
                    <span>曲を追加</span>
                    <input ref={this.setURLRef} type="text" placeholder="URLを入力(Pawoo Music, APPOLO(BOOTH) and YouTube URL)" />
                    <input type="submit" />
                  </form>
                </li>
              </ul>
            </div>
          </div>
        </div>
        <div className='player-seekbar' style={playerSeekBarStyle} />
        <div className='player-control__overlay' onClick={this.handleClickOverlay} />
      </div>
    );
  }
}

MusicPlayer.propTypes = {
  accessToken: PropTypes.string.isRequired
}

export default MusicPlayer;
