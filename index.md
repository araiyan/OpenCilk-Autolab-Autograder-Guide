---
layout: default
title: OpenCilk Autolab Autograder Guide
---

{% capture readme %}
{% include_relative README.md %}
{% endcapture %}

{{ readme | split: '---' | shift | shift | join: '---' | markdownify }}