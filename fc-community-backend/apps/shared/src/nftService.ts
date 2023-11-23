import axios from "axios";
import FormData from "form-data";
import Replicate from "replicate";
import { Note, XCommunityNote } from "./types";
import { S3fileExists, urlToID } from "./utils";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { randomUUID, createHash } from "crypto";


const generateNoteImage = async (
  content: string,
  replicateApiToken: string,
  count = 0,
): Promise<string> => {
  const replicate = new Replicate({
    auth: replicateApiToken,
  });

  try {
    const replicateUrlObj = await replicate.run(
      // replicate identifier of the AI model to run
      "stability-ai/sdxl:c221b2b8ef527988fb59bf24a8b97c4561f1c671f73bd389f866bfb27c061316",
      {
        input: {
          width: 768,
          height: 768,
          prompt: content,
          refine: "expert_ensemble_refiner",
          scheduler: "K_EULER",
          lora_scale: 0.6,
          num_outputs: 1,
          guidance_scale: 7.5,
          apply_watermark: false,
          high_noise_frac: 0.8,
          negative_prompt: "",
          prompt_strength: 0.8,
          num_inference_steps: 25,
        },
      },
    );

    const replicateUrl = (replicateUrlObj as string[])[0];
    console.log(`replicate URL: ${replicateUrl}`);
    return replicateUrl;
  } catch (error) {
    // retry twice if the note generated NSFW image
    // experimentally, chance of success are close to zero after two failures for NSFW content
    if (error instanceof Error && error.message.includes("NSFW") && count < 3) {
      return generateNoteImage(content, replicateApiToken, count + 1);
    } else {
      throw error;
    }
  }
};

const uploadImageToPinata = async (
  replicateUrl: string,
  noteUID: string,
  pinataJwt: string,
): Promise<string> => {
  const imageStream = (
    await axios.get(replicateUrl, { responseType: "stream" })
  ).data;
  const data = new FormData();
  data.append("file", imageStream, {
    filepath: `${noteUID}.png`, // required by the Pinata API
  });
  try {
    const res = await axios.post(
      "https://api.pinata.cloud/pinning/pinFileToIPFS",
      data,
      {
        maxBodyLength: Infinity,
        headers: {
          "Content-Type": `multipart/form-data; boundary=${data.getBoundary()}`,
          Authorization: `Bearer ${pinataJwt}`,
        },
      },
    );
    console.log(res.data);
    return res.data["IpfsHash"];
  } catch (error) {
    throw new Error("Pinata: fails to pin file to IPFS");
  }
};

const uploadMetadataToPinata = async (
  note: Note,
  noteUID: string,
  CID: string,
  pinataJwt: string,
): Promise<string> => {
  try {
    const noteNFTMetadata = JSON.stringify({
      pinataContent: {
        name: `${note.postUrl}`,
        description: `${note.content}`,
        external_url: "https://gateway.pinata.cloud/ipfs/",
        image: `ipfs://${CID}`,
      },
      pinataMetadata: {
        name: `note-${noteUID}-metadata.json`,
      },
    });

    const res = await axios.post(
      "https://api.pinata.cloud/pinning/pinJSONToIPFS",
      noteNFTMetadata,
      {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${pinataJwt}`,
        },
      },
    );
    console.log("Metadata uploaded, CID:", res.data);
    return res.data["IpfsHash"];
  } catch (error) {
    console.log(error);
    throw new Error("Pinata: fails to pin file metadata to IPFS");
  }
};

export const createNFT721DataFromNote = async (
  note: Note,
  replicateApiToken: string,
  pinataJwt: string,
): Promise<string> => {
  if (!note.content) {
    throw new Error("Can't generate image from empty note!");
  }

  const replicateUrl = await generateNoteImage(note.content!, replicateApiToken);
  const noteUID = randomUUID();
  const pinataImageCID = await uploadImageToPinata(
    replicateUrl,
    noteUID,
    pinataJwt,
  );
  const pinataMetadataCID = await uploadMetadataToPinata(
    note,
    noteUID,
    pinataImageCID,
    pinataJwt,
  );
  return pinataMetadataCID;
};


export const getOrcreateNFT1155DatafromXCommunityNote = async (
  note: XCommunityNote,
  replicateApiToken: string,
  AWSAccessKeyID: string,
  AWSSecretAccessKey: string,
  AWSRegion: string,
): Promise<number> => {

  const tokenID = urlToID(note.url);
  const client = new S3Client({
    credentials: {
      accessKeyId: AWSAccessKeyID,
      secretAccessKey: AWSSecretAccessKey,
    },
    region: AWSRegion,
  });

  // Do not create NFT data if token already exist!
  // New token means first mint: we must create the token metadata
  if (!await S3fileExists(client, `${tokenID}.png`)) {
    const replicateUrl = await generateNoteImage(note.content, replicateApiToken);
    const imageBuffer = (
      await axios.get(replicateUrl, { responseType: "arraybuffer" })
    ).data;
    const params = {
      Bucket: "factchain-community",
      Key: `${tokenID}.png`,
      Body: imageBuffer,
      ContentType: "image/png",
    };
    let command = new PutObjectCommand(params);
    try {
      const response = await client.send(command);
      console.log(`Image uploaded successfully. ETag: ${response.ETag}`);
    } catch (error) {
      console.error("Error uploading to S3:", error);
      throw error;
    }
    const tokenMetadata = JSON.stringify({
      name: note.url,
      description: note.content,
      image: `https://factchain-community.s3.eu-west-3.amazonaws.com/${tokenID}.png`,
    });
    params["Key"] = `${tokenID}.json`;
    params["ContentType"] = "application/json";
    params["Body"] = tokenMetadata;
    command = new PutObjectCommand(params);
    try {
      const response = await client.send(command);
      console.log(`Metadata uploaded successfully. ETag: ${response.ETag}`);
    } catch (error) {
      console.error("Error uploading to S3:", error);
      throw error;
    }
  }
  return tokenID
}