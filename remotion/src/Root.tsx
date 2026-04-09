import { Composition } from "remotion";
import { VideoProcessor } from "./VideoProcessor";

// remotion-best-practices: Proper composition setup for post-processing the screen recording.
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="ScreenRecordingProcessor"
        component={VideoProcessor}
        durationInFrames={300}
        fps={60}
        width={1080}
        height={1920}
        defaultProps={{
          title: "Image Recorder App Session",
          videoUrl: "placeholder_recording.mp4",
        }}
      />
    </>
  );
};
