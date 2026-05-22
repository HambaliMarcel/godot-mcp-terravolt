#!/usr/bin/env node
/**
 * Link / unlink TerraVolt Godot addon into a dev project’s `addons/terravolt_mcp`.
 *
 * - `TERRAVOLT_GODOT_PROJECT` absolute path (preferred), or
 * - `~/.terravolt-mcp-dev.json`: `{ "godotProject": "H:/absolute/path/DevProject" }`
 *
 * Usage:
 *   node scripts/addon-link.mjs [--force]
 *   node scripts/addon-link.mjs unlink [--force]
 */
import fs from "fs";

import path from "path";


import { fileURLToPath } from "url";



const __dirname = path.dirname(fileURLToPath(import.meta.url));

const ROOT = path.resolve(__dirname, "..");

const SRC = path.join(ROOT, "packages", "godot-mcp-addon");



function die(msg) {


  console.error(msg);





  process.exit(1);


}



function godotRoot() {


  const e = process.env.TERRAVOLT_GODOT_PROJECT;


  if (e) {


    const r = path.resolve(e);





    if (fs.existsSync(r)) {


      return r;





    }


    die(`TERRAVOLT_GODOT_PROJECT not found: ${r}`);





  }



  const h = process.env.USERPROFILE || process.env.HOME;



  if (!h) {


    die("Set TERRAVOLT_GODOT_PROJECT or HOME/USERPROFILE for config path");


}



  const cfg = path.join(h, ".terravolt-mcp-dev.json");


  if (!fs.existsSync(cfg)) {


    die(`Set TERRAVOLT_GODOT_PROJECT or create ${cfg} with godotProject`);


}



  try {


    const j = JSON.parse(fs.readFileSync(cfg, "utf8"));





    const p = j.godotProject || j.project || j.path;


    if (!p) die(`${cfg}: need godotProject (absolute path)`);


    const root = path.resolve(p);





    if (!fs.existsSync(root)) die(`godotProject path missing: ${root}`);





    return root;



  } catch (err) {


    die(`${cfg}: ${err}`);


}



}



function rmrf(p) {


  fs.rmSync(p, {recursive: true, force: true});


}



function cpTree(from, to) {


  fs.mkdirSync(to, {recursive: true});



  for (const ent of fs.readdirSync(from, {withFileTypes: true})) {


    const sf = path.join(from, ent.name);



    const df = path.join(to, ent.name);





    if (ent.isDirectory()) {


      cpTree(sf, df);





    } else if (ent.isFile()) {


      fs.copyFileSync(sf, df);





    }


  }



}



const argv = process.argv.slice(2);





const force = argv.includes("--force");


const unlinkCmd = argv.includes("unlink");


if (!fs.existsSync(SRC)) {


  die(`Missing addon source folder: ${SRC}`);


}




const proj = godotRoot();


fs.mkdirSync(path.join(proj, "addons"), {recursive: true});


const dest = path.join(proj, "addons", "terravolt_mcp");





if (unlinkCmd) {


  if (!fs.existsSync(dest)) {


    console.log("addon:unlink: nothing at", dest);





    process.exit(0);



  }



  rmrf(dest);


  console.log("addon:unlink removed", dest);



  process.exit(0);



}



if (fs.existsSync(dest) && !force) {


  console.error(`${dest} already exists. Use --force to replace.`);



  process.exit(1);



}






if (fs.existsSync(dest)) {


  rmrf(dest);


}




console.log("addon:link");


console.log("  src", SRC);


console.log("  dst", dest);


try {


  const type = process.platform === "win32" ? "junction" : "dir";





  fs.symlinkSync(SRC, dest, type);



} catch (e) {


  try {


    cpTree(SRC, dest);


    console.warn("Used copy fallback:", e.message);



  } catch (e2) {


    die(String(e2));



  }


}

