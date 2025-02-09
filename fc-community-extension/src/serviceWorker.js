import { getNotes } from './utils/backend';

let cache = {
  postUrl: '',
  creatorAddress: '',
  note: null,
  noteUrl: '',
  content: '',
};

/// For now we deactivate notifications
///
// chrome.notifications.onClicked.addListener(async (postUrl) => {
//   console.log(`Clicked on notification`, postUrl);
//   chrome.tabs.create({
//     url: postUrl
//   });
// });

const mainHandler = async (message, sendResponse) => {
  console.log('Received message', message);

  if (message.type === 'fc-create-note') {
    console.log('Creating a note', message.postUrl);
    cache.postUrl = message.postUrl;

    chrome.windows.create({
      url: 'createNote.html',
      type: 'popup',
      focused: true,
      width: 400,
      height: 600,
      top: 0,
      left: 0,
    });
  } else if (message.type === 'fc-get-notes') {
    const notes = await getNotes({ postUrl: message.postUrl });
    console.log('Retrieved notes', notes);
    sendResponse(notes);
  } else if (message.type === 'fc-rate-note') {
    console.log('Rating note', message.note);
    cache.note = message.note;

    chrome.windows.create({
      url: 'rateNotes.html',
      type: 'popup',
      focused: true,
      width: 400,
      height: 600,
      top: 0,
      left: 0,
    });
  } else if (message.type === 'fc-get-from-cache') {
    console.log(`Get ${message.target} from cache`, cache);
    sendResponse(cache[message.target]);
  } else if (message.type === 'fc-mint-x-note') {
    console.log(
      `Mint X note '${message.noteUrl}' with content '${message.content}'`
    );
    cache.noteUrl = message.noteUrl;
    cache.content = message.content;

    chrome.windows.create({
      url: 'mintXNote.html',
      type: 'popup',
      focused: true,
      width: 400,
      height: 600,
      top: 0,
      left: 0,
    });
  } else if (message.type === 'fc-mint-factchain-note') {
    console.log('Mint Factchain note', message.note);
    cache.postUrl = message.note.postUrl;
    cache.creatorAddress = message.note.creatorAddress;

    chrome.windows.create({
      url: 'mintFactchainNote.html',
      type: 'popup',
      focused: true,
      width: 400,
      height: 600,
      top: 0,
      left: 0,
    });
  } else if (message.type === 'fc-set-address') {
    await chrome.storage.local.set({ address: message.address });
    console.log(`Address set to ${message.address} in storage`);
    sendResponse(true);
  } else if (message.type === 'fc-get-address') {
    const address = (await chrome.storage.local.get(['address'])).address || '';
    console.log(`Retrieved address ${address} from storage`);
    sendResponse({ address });
  }
  /// For now we deactivate notifications
  ///
  // } else if (message.type === "fc-notify") {
  // console.log(`Creating notification for ${message.postUrl}`);
  // chrome.notifications.create(message.postUrl, {
  //   type: 'basic',
  //   iconUrl: 'icons/icon_32.png',
  //   title: message.title,
  //   message: message.content,
  //   buttons: [{ title: 'Take me there' }],
  //   priority: 2
  // });
};

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  mainHandler(message, sendResponse);
  return true;
});

console.log('Initialised');
