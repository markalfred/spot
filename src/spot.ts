require("dotenv").load();
import temp from "temp";
import request from "request";

interface IRequestOptsHeaders {
  Authorization: string;
}

interface IRequestOpts {
  headers: IRequestOptsHeaders;
}

let REQUEST_OPTS: IRequestOpts | null = null;
let IMG_DIR: string | null = null;
let SOUND_DIR: string | null = null;

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

interface IRequestForm {
  grant_type: string;
}

// Request Lib may have a type for this
interface IRequestOptions {
  url: string;
  headers: IRequestOptsHeaders;
  json: boolean;
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
    },
    json: true
  };

  request.post(authOptions, function(error, response, body) {
    if (!error && response.statusCode === 200) {
      const token: string = body.access_token;
      const options: IRequestOptions = {
        url: `https://api.spotify.com/v1/users/${process.env.USERNAME}`,
        headers: {
          Authorization: `Bearer ${token}`
        },
        json: true
      };
      request.get(options, function(error, response, body) {
        console.log(body);
      });
    }
  });
};
