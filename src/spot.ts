require("dotenv").load();
import * as temp from "temp";
import * as request from "request";
import * as blessed from "blessed";
import * as _ from "lodash";

interface IRequestOptsHeaders {
  Authorization: string;
}

interface IRequestOpts {
  headers: IRequestOptsHeaders;
}

let REQUEST_OPTS: IRequestOpts | null = null;
let IMG_DIR: string | null = null;
let SOUND_DIR: string | null = null;
let AUTH_TOKEN: string | null = null;

const setup = (): void => {
  getToken();
  temp.track();
  temp.mkdir("images", (err, dirPath): void => {
    IMG_DIR = dirPath;
  });
  temp.mkdir("sound", (err, dirPath): void => {
    SOUND_DIR = dirPath;
  });
};

const render = (): void => {
  playlists.focus();
  screen.render();
};

interface IRequestForm {
  grant_type: string;
}

// Request Lib may have a type for this
interface IRequestOptions {
  url: string;
  headers: IRequestOptsHeaders;
}

interface IAuthOptions extends IRequestOptions {
  form: IRequestForm;
}

const getToken = (): void => {
  const authOptions: IAuthOptions = {
    url: "https://accounts.spotify.com/api/token",
    headers: {
      Authorization: `Basic ${new Buffer(
        `${process.env.CLIENT_ID}:${process.env.CLIENT_SECRET}`
      ).toString("base64")}`
    },
    form: {
      grant_type: "client_credentials"
    }
  };

  request.post(authOptions, function(error, response, body) {
    if (!error && response.statusCode === 200) {
      AUTH_TOKEN = JSON.parse(body).access_token;
      REQUEST_OPTS = { headers: { Authorization: `Bearer ${AUTH_TOKEN}` } };
      render();
      getPlaylists();
    }
  });
};

const getPlaylists = () => {
  const options: IRequestOptions = {
    url: `https://api.spotify.com/v1/users/${
      process.env.USERNAME
    }/playlists?limit=50`,
    headers: {
      Authorization: `Bearer ${AUTH_TOKEN}`
    }
  };

  request.get(options, function(error, response, body) {
    if (error) {
      console.log(error);
    }
    const playlistJson = JSON.parse(body);

    playlists.setItems(_.map(playlistJson.items, "name"));
    screen.render();
  });
};

var screen = blessed.screen({
  smartCSR: true,
  dockBorders: true
});

screen.title = "Spot";

const title = blessed.text({
  parent: screen,
  top: "top",
  left: "center",
  align: "center",
  height: 1,
  style: {
    fg: "green"
  },
  tags: true,
  content: "{bold} Spot {/}"
});

const sidebar = blessed.box({
  parent: screen,
  top: title.height,
  left: 0,
  height: `100%-${title.height}`,
  border: "line"
});

const maxWidth = 40;
if (sidebar.width > maxWidth) {
  sidebar.width = maxWidth;
}

const playlists = blessed.list({
  parent: sidebar,
  top: 0,
  left: 0,
  height: "shrink",
  width: "100%-2",
  scrollable: true,
  mouse: true,
  keys: true,
  vi: true,
  content: "Loading...",
  padding: {
    top: 0,
    right: 1,
    bottom: 0,
    left: 1
  },
  style: {
    item: { fg: "grey" }
  },
  scrollbar: { ch: " " }
});

setup();

screen.key("q", () => {
  process.exit(0);
});
