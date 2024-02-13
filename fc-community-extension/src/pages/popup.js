import { render } from 'solid-js/web';
import { createSignal, Switch, Match, createResource } from 'solid-js';
import { createFactchainProvider } from '../utils/web3';
import { FCHero, FCLoader, FCContainer, FCHeader } from './components';
import { getNotes } from '../utils/backend';
import { ethers } from 'ethers';
import { cutText, elipseText } from '../utils/constants';

import './style.css';

function FCProfile(props) {
  function StatCard(props) {
    return (
      <div className="text-center">
        <div className="font-bold text-xl">{props.value}</div>
        <div className="text-md opacity-50">{props.name}</div>
      </div>
    );
  }

  return (
    <FCContainer>
      <div className="space-y-8 min-h-full flex flex-col">
        <div className="flex-grow space-y-8">
          <div className="flex items-center w-5/6 mx-auto bg-neutral-950/30 py-2 px-4 rounded gap-4 shadow-md border border-neutral-950/40">
            <div className="rounded-full w-[40px] h-[40px] bg-neutral-400/30 shadow"></div>
            <div className="flex-grow">
              <div className="font-semibold text-xl">Account</div>
              <div className="opacity-70">
                {props.loggedIn ? elipseText(props.address, 20) : '0x?'}
              </div>
            </div>
          </div>
          <div className="flex items-center justify-between bg-neutral-400/10 rounded-2xl px-10 py-6">
            <StatCard name="Notes" value={props.numberNotes} />
            <StatCard name="Ratings" value={props.numberRatings} />
            <StatCard name="Earnings" value={props.earnings} />
          </div>
        </div>
        <button
          className="w-full p-4 font-semibold text-base btn"
          onclick={props.changeConnectionState}
        >
          {props.loggedIn ? 'Log out' : 'Connect a wallet'}
        </button>
      </div>
    </FCContainer>
  );
}

function FCNotes(props) {
  const [notes] = createResource(() => getNotes(props.queryparams));

  function FCNote({ postUrl, content, creator }) {
    return (
      <div
        key={postUrl}
        style="background-color: #393E46; padding: 10px; border-radius: 10px;"
      >
        <div>
          <a href={postUrl} target="_blank">
            {cutText(postUrl, 35)}
          </a>
        </div>
        <div>{cutText(content, 115)}</div>
        <div style="display: flex; justify-content: flex-end; font-style: italic;">
          -- {creator}
        </div>
      </div>
    );
  }

  return (
    <FCContainer>
      <Switch>
        <Match when={!props.loggedIn}>
          <div className="h-full flex flex-col justify-center items-center">
            <div className="link text-lg" onclick={props.connectWallet}>
              Connect a wallet
            </div>
            <div>to view Factchain notes</div>
          </div>
        </Match>
        <Match when={notes() !== undefined}>
          <div className="space-y-2">
            <For each={notes()}>
              {(note) => (
                <FCNote
                  key={note.postUrl}
                  postUrl={note.postUrl}
                  creator={note.creatorAddress}
                  content={note.content}
                />
              )}
            </For>
          </div>
        </Match>
        <Match when={true}>
          <div style="position: relative; top:50%; left: 50%; transform: translate(-50%, -50%);">
            <FCLoader />
          </div>
        </Match>
      </Switch>
    </FCContainer>
  );
}

function FCFooter(props) {
  function FCFooterTab(props) {
    const selected = () => props.name === props.selectedTab;
    const classes = () => `tab ${selected() ? 'selected' : ''}`;
    const imgSrc = `./${props.name.toLowerCase()}.svg`;
    return (
      <button
        class={classes()}
        onclick={() => props.onClick(props.name)}
        title={props.name}
      >
        <img className="w-[18px] h-[18px]" src={imgSrc} alt={props.name}></img>
      </button>
    );
  }
  return (
    <div className="flex items-center justify-between bg-fcGrey py-2 px-6">
      <FCFooterTab
        name="Profile"
        selectedTab={props.selectedTab}
        onClick={props.setSelectedTab}
      />
      <FCFooterTab
        name="Notes"
        selectedTab={props.selectedTab}
        onClick={props.setSelectedTab}
      />
      <FCFooterTab
        name="Ratings"
        selectedTab={props.selectedTab}
        onClick={props.setSelectedTab}
      />
    </div>
  );
}

function FCPopup({ provider }) {
  const [selectedTab, setSelectedTab] = createSignal('Profile');
  const [address, setAddress] = createSignal('');
  const loggedIn = () => !!address();

  const changeConnectionState = async () => {
    setSelectedTab('Profile');
    if (loggedIn()) {
      await provider.disconnect();
      await chrome.runtime.sendMessage({
        type: 'fc-set-address',
        address: '',
      });
      setAddress('');
    } else {
      await provider.requestAddress().then(setAddress);
    }
  };
  const getUserStats = async (address) => {
    console.log(`address: ${address}`);
    if (address) {
      const contract = await provider.getMainContract();
      const stats = await contract.userStats(address);
      console.log(`User stats: ${stats}`);
      const earnings = `${Math.max(Number(stats[2] - stats[3]), 0)}`;
      return {
        notes: `${stats[0]}`,
        ratings: `${stats[1]}`,
        earnings: `${ethers.formatEther(earnings)} ETH`,
      };
    } else {
      console.log(`Default data for user stats`);
      return {
        notes: '?',
        ratings: '?',
        earnings: '? ETH',
      };
    }
  };
  const [userStats] = createResource(address, getUserStats);
  const numberNotes = () =>
    userStats.ready || !userStats() ? '?' : userStats().notes;
  const numberRatings = () =>
    userStats.loading || !userStats() ? '?' : userStats().ratings;
  const earnings = () =>
    userStats.loading || !userStats() ? '? ETH' : userStats().earnings;
  provider.getAddress().then(setAddress);

  return (
    <div className="h-[575px] w-[375px] flex flex-col">
      <Switch>
        <Match when={selectedTab() === 'Profile'}>
          <FCHero />
          <FCProfile
            provider={provider}
            loggedIn={loggedIn()}
            address={address()}
            changeConnectionState={changeConnectionState}
            numberNotes={numberNotes()}
            numberRatings={numberRatings()}
            earnings={earnings()}
          />
        </Match>
        <Match when={selectedTab() === 'Notes'}>
          <FCHeader title="My notes" />
          <FCNotes
            loggedIn={loggedIn()}
            queryparams={{ creatorAddress: address() }}
            connectWallet={changeConnectionState}
          />
        </Match>
        <Match when={selectedTab() === 'Ratings'}>
          <FCHeader title="Ratings" />
          <FCNotes
            loggedIn={loggedIn()}
            queryparams={{ awaitingRatingBy: address() }}
            connectWallet={changeConnectionState}
          />
        </Match>
      </Switch>
      <FCFooter selectedTab={selectedTab()} setSelectedTab={setSelectedTab} />
    </div>
  );
}

const provider = await createFactchainProvider();

render(() => <FCPopup provider={provider} />, document.getElementById('app'));
