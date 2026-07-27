import React from "react";
import { Composition, registerRoot } from "remotion";
import { NotchDeckDemo } from "./compositions/NotchDeckDemo";

const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="NotchDeckDemo"
        component={NotchDeckDemo}
        durationInFrames={900}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="NotchDeckLandscape"
        component={NotchDeckDemo}
        durationInFrames={900}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};

registerRoot(RemotionRoot);
