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
Before applying the fix, identify the sound card containing the Realtek ALC289 codec:

```bash
grep -H '^Codec:' /proc/asound/card*/codec*
```

On the test machine, the relevant output is:

```text
/proc/asound/card1/codec#0:Codec: Realtek ALC289
```

This corresponds to the hardware device `/dev/snd/hwC1D0`.

ALSA sound card numbering may differ between machines. If your ALC289 codec is assigned a different card or codec number, adjust the device paths throughout this guide accordingly.

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

The manual `hda-verb` commands change the codec state immediately,
but that state is not guaranteed to persist across login, reboot,
user switching or suspend/resume.

HDA runtime power saving can cause pin `0x17` to return to its
disabled state. However, testing established that the pin can
also be reset during user session changes, even with HDA runtime
power saving disabled.

Several approaches based on startup delays and audio service
readiness were tested but did not provide a reliable solution.

The final working solution uses a state-aware watcher that
monitors HDA node `0x17` once per second. If the output pin is
no longer enabled, the watcher automatically reapplies the two
`hda-verb` commands.

The persistent configuration consists of:

- A watcher script that monitors and restores the woofer output.
- A systemd user service that starts and supervises the watcher.
- Restricted sudo permissions for the two required HDA commands.
- A suspend/resume hook that restores the woofer output.
- A configuration file that disables HDA runtime power saving.

This configuration has been in continuous everyday use on the
test machine since 30 September 2026 and was confirmed stable
on 25 November 2026.

### Install the persistent fix

Once you have confirmed that the manual fix restores the missing bass, clone this repository and run the installer:

```bash
sudo ./install.sh
```

The installer configures the automatic woofer fix, disables HDA runtime power saving, and installs the suspend/resume hook.

Reboot the computer when the installer has finished.

After reboot, play some bass-heavy music and confirm that the woofers are still working without manually running the `hda-verb` commands.

### Uninstall the fix

To remove the persistent audio workaround, run:

```bash
sudo ./uninstall.sh
```

Reboot the computer to complete the removal.

The uninstaller removes all five configuration components,
disables the systemd user service and rebuilds the initramfs.

It does not remove any installed packages or restore
pre-existing configuration files overwritten during installation.

## Tested configuration

- Hardware: Alienware x17 R1
- Operating system: Linux Mint 22.3
- Kernel: 7.0.0-44-generic
- Audio stack: ALSA, PipeWire and WirePlumber
- Last tested: 25 November 2026

The persistent fix has been in everyday use since
30 September 2026 without reported recurrence of
the original audio problem.

Both the installation and uninstallation scripts
were successfully tested on 25 November 2026.

Compatibility with other Linux distributions and
hardware configurations has not yet been verified.

## Known limitations

The test machine has a pre-existing fault affecting the right
woofer. This fault is present under both Windows and Linux
and was not resolved by replacing the complete speaker
assembly and wiring harness.

The Linux fix successfully restores the left woofer, which

## Technical investigation

### Approaches tested

Before arriving at the final working configuration,
several alternative approaches were investigated:

- Setting the ALSA model parameter to `alienware`.
- Applying HDA commands during system startup.
- Applying HDA commands after the audio services started.
- Introducing fixed startup delays.
- Waiting for the default PipeWire audio sink to become available.
- Reapplying the HDA commands at timed intervals.
- Disabling HDA runtime power saving.

None of these approaches alone provided a reliable,
persistent solution.

The significant discovery was that HDA node `0x17`
could return to its disabled state during user session
switching, even with HDA runtime power saving disabled.

This led to the development of the state-aware watcher,
which restores the output whenever the pin is detected
in a disabled state, rather than relying on predicted
startup timings.
has remained stable since 30 September 2026.

It has not been possible to verify both woofer channels on
a machine with fully functioning audio hardware.
