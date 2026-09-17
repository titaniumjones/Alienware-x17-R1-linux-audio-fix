# Alienware-x17-R1-linux-audio-fix
Linux audio fix for the Alienware x17 R1. Enables the internal woofers/subwoofers driven by the Realtek ALC1309 alongside the ALC3281/ALC289 codec. Documents the ALSA/HDA configuration, speaker topology, troubleshooting, hardware findings and known limitations.

## The problem
The Alienware x17 R1 uses a four-speaker audio system consisting of two tweeters and two woofers. Under Linux, the Realtek ALC289/ALC3281 codec is detected, but the ALC1309-driven woofers are not correctly enabled by the standard audio configuration.
The result is working internal audio, but with the woofers silent. The laptop therefore sounds extremely thin and lacks the low-frequency output present under Windows.
This repository documents the investigation and a working Linux configuration which enables the woofer audio path.

## Audio hardware
The Alienware x17 R1 has four internal speakers:

- 2 × tweeters
- 2 × woofers

The Linux HDA driver identifies the main Realtek codec as:

    Realtek ALC289

Dell documentation identifies the audio controller as the Realtek ALC3281. The two woofers are additionally driven through a Realtek ALC1309 amplifier.
This distinction is important: seeing the ALC289 codec and obtaining working audio from the laptop does not necessarily mean that the complete four-speaker system is operating.
On the x17 R1, the woofer path requires additional configuration that is not provided correctly by the default Linux audio setup.

## The fix
On the Alienware x17 R1, Linux does not reliably keep the woofer output on HDA node `0x17` enabled.

The working configuration consists of three parts:

1. Enable HDA node `0x17` as an output.
2. Unmute the output amplifier on HDA node `0x17`.
3. Disable HDA runtime power saving, because it can reset node `0x17` back to a disabled state after login or idle.

### 1. Test the woofer path manually

The woofer path can be enabled manually with:

```bash
# Configure HDA pin 0x17 as an output
sudo hda-verb /dev/snd/hwC1D0 0x17 0x707 0x40

# Unmute the output amplifier on node 0x17
sudo hda-verb /dev/snd/hwC1D0 0x17 0x300 0xa000
```

### Verify the fix

First, listen to some music with strong bass content. The difference should be immediately noticeable: the internal speakers should sound substantially fuller, with low-frequency output that was absent before.

You can confirm that pin `0x17` is now enabled with:

```bash
grep -A12 'Node 0x17' /proc/asound/card1/codec#0
```

The output should include:

```text
Pin-ctls: 0x40: OUT
```

Before applying the fix, this was:

```text
Pin-ctls: 0x00:
```

### Make the fix persistent

The manual `hda-verb` commands change the codec state immediately, but that state is not guaranteed to persist across login, reboot or suspend/resume.

There is also a second problem: HDA runtime power saving can reset pin `0x17` back to its disabled state after the fix has been applied.

The permanent workaround therefore needs to:

- reapply the two `hda-verb` commands automatically after the audio system starts;
- reapply them after suspend/resume;
- disable HDA runtime power saving so that the working codec state is not subsequently reset.

An installation script is provided to configure these changes automatically.

### Install the persistent fix

Once you have confirmed that the manual fix restores the missing bass, clone this repository and run the installer:

```bash
sudo ./install.sh
```

The installer configures the automatic woofer fix, disables HDA runtime power saving, and installs the suspend/resume hook.

Reboot the computer when the installer has finished.

After reboot, play some bass-heavy music and confirm that the woofers are still working without manually running the `hda-verb` commands.
