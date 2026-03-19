# FAQ OpenCilk Autolab

- Where would Autolab be run on?
  - University Machine (Talk to the IT Department to set up)

- What about authentication? How does it work with Autolab running on a VM?

  - Autolab has its own email authentication service. You'd need to set up an emailing server. (Ask the IT department)
  - Autolab has a login portal

- What happens if the job is long-running?

  - If there are multiple jobs, they will automatically get queued up inside Tango Backend
  - If one job takes too long it will timeout in 180 seconds by default. This can be configured in the settings.

- “git push” runs action in gitlab server, with this it’s always web submission?

  - Autolab allows for github submission, you'd have to configure git one time, then this feature can be enabled on each assessment

- Looks good for single-source-files as opposed to more complex multi-file

  - Autolab support tar file submissions by default, so you can submit your entire work folder to autolab.

- Can you set up so there’s a timeout on jobs?

  - Yes, go to Edit Assessment → Under modules users - Autograder Settings → Timeout

- With git pushes, could you have multiple autolab instances? One to submit to a local machine for testing, then one for final submission to a big machine? 

  - Each instance of autolab can be run on different domains. So as long as you have two domain names and run them separately this can be done

- Can I run this locally?

  - Yes, but have to set up port forwarding. Your local machine doesn’t have routing services.

- Can your Docker container have consistent storage or is it ephemeral file system? What if I had a storage-system-performance assignment that actually touched a disk that wasn’t a RAM disk?

  - Autolab Makefile removes work files after autograding each assignment. If you wanted to have persistent storage you'd have to omit this part and set up a script to be able to handle persistent disk storage and retrieval.

