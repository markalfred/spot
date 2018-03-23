import dotenv from "dotenv";
import { map, extend } from "lodash";
import fs from "fs";
import ps from "child_process";
import temp from "temp";
import moment from "moment";
import request from "request";
import blessed from "blessed";
function greeter(person: string): string {
  return "Oh hai, " + person;
}

export { greeter };
