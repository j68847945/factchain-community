import { render } from "solid-js/web";
import { createFactCheckProvider } from "../utils/web3";
import { Popup } from "./components";

const provider = await createFactCheckProvider();

render(() => <Popup provider={provider} />, document.getElementById("app"));
