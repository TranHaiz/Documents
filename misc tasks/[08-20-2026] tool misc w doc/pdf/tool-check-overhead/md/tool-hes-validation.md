# HES FDA Toolkit — Usage Guide

## Revision History

| **Date**   | **Version** | **Author** | **Note**        |
| ---------- | ----------- | ---------- | --------------- |
| 2026-08-12 | 1.0         | Hau Pham   | Initial version |

## Prerequisites

- **Python 3.x** installed:

  ```
  python --version
  ```

- **WSL Ubuntu-22.04** installed (required for **WFDB 10.7.0** — the EC57 scoring library):

  ```
  wsl --install -d Ubuntu-22.04
  ```

- Run **setup.bat** once:

  ```
  setup.bat
  ```

- **Launch the UI:**

  ```
  run.bat
  ```

## Overview

Evaluate the HES arrhythmia algorithm against ANSI/AAMI EC57:1998 (FDA-recommended) for Beat Detection and AFIB Event Detection, using technician annotations as the reference. The workflow is shown below:

![](images/tool-hes-validation-image-001.png)

### Beat Detection

Each beat HES marks is matched, within a small time window, to the technician's beats:

- **True Positive (TP)** — an HES beat that matches a reference beat.
- **False Positive (FP)** — an HES beat with no reference beat (a false detection).
- **False Negative (FN)** — a reference beat that HES missed.

![](images/tool-hes-validation-image-002.png)

**Beats are graded by AAMI class:**

1. **N:** Normal beat
2. **V:** Ventricular ectopic (PVC)
3. **S:** Supraventricular ectopic (PAC)
4. **Q:** All beats

| **Metric** | **Formula**       | **Meaning**                             |
| ---------- | ----------------- | --------------------------------------- |
| **Q_Se**   | TP / (TP + FN)    | Sensitivity for **all beats**           |
| **Q_+P**   | TP / (TP + FP)    | Positive Predictivity for **all beats** |
| **V_Se**   | VTP / (VTP + VFN) | Sensitivity for **V beats**             |
| **V_+P**   | VTP / (VTP + VFP) | Positive Predictivity for **V beats**   |
| **S_Se**   | STP / (STP + SFN) | Sensitivity for **S beats**             |
| **S_+P**   | STP / (STP + SFP) | Positive Predictivity for **S beats**   |

### AFIB Event Detection

AFIB episodes are matched against technician annotations using TP/FP/FN.

An episode is a TP if it overlaps a reference episode, FN if missed, and FP if false. Metrics: E_Se and E_+P.

![](images/tool-hes-validation-image-003.png)

**Duration** — every second is TP / FN / FP. → **D_Se**, **D_+P**.

![](images/tool-hes-validation-image-004.png)

| **Metric** | **Level** | **Formula**              | **Meaning**                     |
| ---------- | --------- | ------------------------ | ------------------------------- |
| **E_Se**   | Episode   | Detected / Reference     | AFIB episodes detected          |
| **E_+P**   | Episode   | True detected / Detected | Detected episodes that are true |
| **D_Se**   | Duration  | TP / (TP + FN)           | True AFIB time detected         |
| **D_+P**   | Duration  | TP / (TP + FP)           | Detected AFIB time that is true |

**Specificity & NPV — the non-AFIB side**

The run also evaluates non-AFIB time (TN). Specificity uses reference non-AFIB time (FP + TN), while NPV uses HES non-AFIB time (FN + TN).

![](images/tool-hes-validation-image-005.png)

| **Metric**                                     | **Formula**            | **Meaning**                                                     |
| ---------------------------------------------- | ---------------------- | --------------------------------------------------------------- |
| **D_Spec** — duration specificity              | **TN / (TN +** **FP)** | of the true non-AFIB time, how much HES correctly left non-AFIB |
| **D_NPV** — duration negative predictive value | **TN / (TN +** **FN)** | of HES's non-AFIB time, how much is truly non- AFIB             |

**Gross (pooled), not averaged**

Every number in the report is **gross (pooled)**: sum the raw counts across **all** records first, then take **one** ratio — never the average of per-record percentages. Averaging would let a 20-beat record count the same as a 2,000-beat one, and a record with no reference beats has no percentage to average at all.

Example — **Q_Se = TP / (TP + FN)** over two records:

| **Record** | **TP**    | **FN** | **per-record Q_Se**       |
| ---------- | --------- | ------ | ------------------------- |
| A          | 90        | 10     | 90.0%                     |
| B          | 990       | 10     | 99.0%                     |
| **Gross**  | **1,080** | **20** | **1,080 / 1,100 = 98.2%** |

The **average** of the two percentages is 94.5%, but the **gross** is **98.2%** — record B's 1,000 beats carry more weight. Every metric pools this way: beats sum TP / FN / FP; AFIB duration and Spec/NPV sum the AFIB seconds and TN / FP / FN. This is exactly why the **metric merge** and **filter / greedy** tabs re-pool the raw counts instead of averaging percentages.

## High level workflow

Validating the HES algorithm for FDA submission is an **iterative** process between the **backend team**, the **firmware team**, and a **technician**.

![](images/tool-hes-validation-image-006.png)

## Dataset

### Full dataset (current)

Hosted on SharePoint: full-dataset.

**12,870** events in total — **1,452** already technician-labeled and **11,418** not yet technician-labeled. Grouped by reference source (Tech / AI), rhythm, and FBD:

![](images/tool-hes-validation-image-007.png)

### Selected 900 events for FDA

Hosted on SharePoint: 900-event set.

The validation set submitted for FDA — **900** events across five rhythm types:

![](images/tool-hes-validation-image-008.png)

## Validate tab - EC57 comparison

![](images/tool-hes-validation-image-009.png)

Fill the fields, then press **Run**. The metrics land in the report table under the log and are written to the output **metrics_summary.xlsx**.

### Input

![](images/tool-hes-validation-image-010.png)

Each **<eventId>/** sub-folder must contain the **four** files below:

| **File**  | **What it holds**                                                                           |
| --------- | ------------------------------------------------------------------------------------------- |
| **.dat**  | Record file — the raw ECG samples (200 Hz) for the event                                    |
| **.hea**  | Header file — record name, sample rate, format, sample count; **describes the .dat**        |
| **.json** | Metadata shown on the ECG labeling portal — the **AI / technician** beats + AFIB annotation |
| **.ann**  | The beats + AFIB annotation produced by the **HES algorithm running on the device**         |

### Parameters

Defaults in brackets. The three timing-related fields are illustrated below.

| **Parameter**                     | **Default** | **Description**                               |
| --------------------------------- | ----------- | --------------------------------------------- |
| **SourceVerify**                  | AI          | Reference: **Tech** or **AI**                 |
| **FilterByDetectedSample (FBD)**  | on          | Score only within the device detection window |
| **CalibTime**                     | 0           | Skip first N seconds; used when FBD is off    |
| **BeatErr**                       | 0.15        | Beat-match window for **bxb**, in seconds     |
| **RemoveBlankAnn**                | on          | Exclude events with no detection              |
| **Add Spec/NPV to output**        | on          | Add **D_Spec** / **D_NPV** columns            |
| **Spec/NPV on AFIB records only** | on          | Calculate Spec/NPV using AFIB records only    |

**FilterByDetectedSample (FBD)**

When the original **.ann** cannot be found, the event is re-run on the device, which detects nothing during its **calibration warm-up**. **FBD = on** trims the reference up to the device's **first detected beat**, so the warm-up is not scored as missed beats (**CalibTime** unused); **FBD = off** scores the full strip. Details: ecgSD Firmware Workflow and Usage Guide.

![](images/tool-hes-validation-image-011.png)

**CalibTime**

skip the **first N seconds** of both reference and device. 0 keeps all.

![](images/tool-hes-validation-image-012.png)

**BeatErr**

The bxb tolerance matches a device beat to a reference beat within ± BeatErr seconds. Otherwise, the device beat is an FP and the reference beat is an FN. The default BeatErr is **0.15 s**, based on WFDB 10.7.0.

![](images/tool-hes-validation-image-013.png)

### Example - Validate Brady dataset

The 900-event dataset is the merged result of six smaller datasets, as shown below:

![](images/tool-hes-validation-image-014.png)

This example validates the Brady dataset from the selected 900-event dataset. Follow the steps below:

1. **Download** the **Brady** brady 900_event_source,

![](images/tool-hes-validation-image-015.png)

1. **Input**: set the **Input data folder** to the Brady folder.
2. **Output folder**: a real project path such as **..\test-data\metric-merge** (not a temp folder); the file name auto-fills.
3. **Auto-filled**: the folder's **validate_config.json** fills **SourceVerify = Tech · FBD = off · CalibTime = 0 · BeatErr = 0.15 · RemoveBlankAnn = on**.
4. **Run / Open output**: press **Run**; when it finishes, **Open output** opens the saved **brady.xlsx**.
5. **Result / Copy table**: the EC57 metrics appear in the report table; **Copy table** copies them.

Open **brady.xlsx** (via **Open output**): it has **6 sheets** (the **summary** sheet is shown):

![](images/tool-hes-validation-image-016.png)

- **summary** — the gross metrics (one row).
- **report** / **mail_table** — the report-table view shown under the log.
- **bxb_line_sumstats** — per-record beat counts (Q / V / S) behind Q_Se, V_Se, S_Se.
- **epicmp_sumstats** — per-record AFIB episode + duration counts behind E_Se / D_Se and AFIB_dur_Spec / NPV.
- **excluded_records** — records dropped from scoring (if any).

The two per-record sheets are exactly what **metric merge** re-pools across groups.

## Merge tab

As noted above, the selected **900-event** set is the **merge of six sub-sets** (one per rhythm × FBD). This tab pools them into one gross result.

**Download all six sub-sets** from SharePoint and **validate** each one → six metrics **.xlsx** (each like the Brady run above). Then follow the markers 1-4:

![](images/tool-hes-validation-image-017.png)

1. **Inputs** — Add the six **.xlsx** files or select a folder containing them.
2. **Run** — Merge the datasets.
3. **Pooled** — Verify the merged counts total 900 events.
4. **Result** — View the pooled EC57 metrics; **Copy table** to copy the results.

Pooling the six groups gives the locked EC57 result for the 900 set:

| **Strip** | **Q_Se** | **Q_+P** | **V_Se** | **V_+P** | **S_Se** | **S_+P** | **E_Se** | **E_+P** | **D_Se** | **D_+P** | **D_Spec** | **D_NPV** |
| --------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | -------- | ---------- | --------- |
| 900       | 97.04    | 98.43    | 82.41    | 14.74    | 23.39    | 9.85     | 96.5     | 97.31    | 95.54    | 95.59    | 85.68      | 85.54     |

## Cut ann tab

When BE provides the event folders, the **.ann** files are missing because annotations are stored in the study's **.anb** file. **Cut ann** rebuilds each event folder using the **.anb** file and event JSON (**studyId, start, stop**).

![](images/tool-hes-validation-image-018.png)

**Run it:**

1. **Download** the cut-ann sample from SharePoint and extract it to **..\test-data\cut-ann**.

![](images/tool-hes-validation-image-019.png)

1. **JSON folder** = ..\test-data\cut-ann\afib\json
2. **Study data folder** = ..\test-data\cut-ann\afib\anb
3. **Output folder** = Event folders in **..\test-data\cut-ann\afib\event** containing **.dat/.hea/.json**; **Cut ann** adds the **.ann** file.
4. **Run** — Cuts the **.ann** for each event, renames all four files to the same **<base>**, and updates the **.hea** record name. **Remove incomplete** deletes folders missing any of the 4 files.

## Ann to device tab

**ann to device** copies the device's beats and AFIB from **.ann** to the event JSON's **aiPrediction**, replacing the AI result. This allows the technician to review the device's actual detection on the ECG portal.

![](images/tool-hes-validation-image-020.png)

It writes beats, **hesBeatStatus**, and AFIB **rhythm** runs into **aiPrediction**.

**Run it:**

1. **Download** the sample from SharePoint and extract it to **..\test-data\ann-to-device\input**.

![](images/tool-hes-validation-image-021.png)

1. **Source folder** = **..\test-data\ann-to-device\input** (5 event folders with **.ann/.dat/.hea/.json**).
2. **Output folder** = any folder (e.g. **..\test-data\ann-to-device\output**).
3. **Run** — writes device **.ann** data to each **.json**'s **aiPrediction**.
4. **Result** — **5/5 events converted · 3,221 beats · 4 AFIB runs**. **Confirm** — Re-run **validate** with **SourceVerify = AI**. All metrics should be **100%** because the device **.ann** and **aiPrediction** contain the same device results.

![](images/tool-hes-validation-image-022.png)

## Event types tab

**Event types** assigns each event one rhythm (AFIB, Brady, Tachy, Pause, or Sinus/Other) for dataset accounting.

**Classification** — Based on the **rhythm** and **interpretation** fields in the **.json** `strip` (technician label).

```
"strip": {
  "rhythm": [
    {
      "type": "AFIB",
      "isDeleted": false,
      "start": 47,
      "stop": 149942
    }
  ],
  "interpretation": "Atrial Fibrillation/Flutter"
}
```

**AFIB: strip.rhythm** contains a non-deleted **AFIB** run.

**Pause / Tachy / Brady:** detected by keywords in **strip.interpretation**.

If **strip.interpretation** is blank or **"agree"**, use **aiPrediction.interpretation**.

The table below shows the rules with an example from the 900-event dataset.

| **Rhythm**                                                | **Fires when**                                                                                          | **Example**                 | **(real event)**                                               |                                                   |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- | --------------------------- | -------------------------------------------------------------- | ------------------------------------------------- |
| **AFIB**                                                  | **strip.rhythm** has a run with type = AFIB, not deleted                                                | rhythm the text)            | run **type = AFIB** (from                                      | (from the field, not                              |
| **Pause**                                                 | **strip.interpretation** contains **pause**                                                             | "Sinus with                 | Rhythm at 46 bpm and SVE."                                     | and Pause 2.7s                                    |
| **Tachy**                                                 | **strip.interpretation** contains **tachy**                                                             | "Sinus PVCs"                | Tachycardia, Ventricular                                       | Trigeminals,                                      |
| **Brady**                                                 | **strip.interpretation** contains **brady**                                                             | "Sinus and                  | Bradycardia with Sinus PACs"                                   | Arrhythmia                                        |
| **Sinus/Other** **Multi-rhythm** **Event interpretation** | none of the above fired **events:** Apply priority **AFIB > Pause > Tachy >** **interpretation (real)** | "3rd Deg Runs" **Brady** so | Deg AVB with SVEs, SVE each event belongs to **Rules matched** | Couplets, SVE one bucket. **Kept** **(priority)** |
| "**Bradycardia** 69; Sinus 52"                            | 29 bpm and **Pause** 4.4s; **Atrial Fibrillation/Flutter**                                              | 35-                         | AFIB · Pause · Brady                                           | **AFIB**                                          |
| "2nd degree AV 54"                                        | AV Block 26 bpm and **Pause** 2.5s; **Bradycardia** 27;                                                 | Sinus                       | Pause · Brady                                                  | **Pause**                                         |
| "**Atrial**                                               | **Fibrillation/Flutter** 93-233; Sinus **Tachycardia** 144"                                             |                             | AFIB · Tachy                                                   | **AFIB**                                          |

**Note:** AFIB is determined by the **rhythm** field, not interpretation text. Only **Pause / Tachy / Brady** use text matching.

**Run** on the 900-event set using steps 1–4 below.

![](images/tool-hes-validation-image-023.png)

1. **Input** — **Event folder** = **..\test-data\metric-merge\input-old-97** (the folder holding the event groups).
2. **Output xlsx** = anywhere.
3. **Run**.
4. **Result** — **TOTAL 900**, one rhythm per event: **AFIB 300 · Brady 125 · Tachy 125 · Pause 50 · Sinus/Other 300 = 900** (source **car5 130 / tech 770**).

The output **.xlsx** — a **Summary** with the counts plus one sheet per rhythm (**friendlyId / recordHash / source / interpretation**):

![](images/tool-hes-validation-image-024.png)

## Filter tab

One tab with two curation modes:

- **greedy** — keeps the best **N** records using maximin.
- **flag** — removes records below a fixed metric threshold.

Both modes recompute metrics for the remaining records and output the **selected** set. **flag** also outputs a **flagged** sheet. Input: one or more validation **.xlsx** files.

### Demo data

1. **Download** the demo pools from SharePoint:
- **demo_filter.xlsx** — 10 records for **greedy** and all **flag** modes.
- **demo_ceil.xlsx** — 6 records for **Ceil** mode only.

Select the relevant file in **Inputs** before running.

### Greedy

**Mode = greedy** removes records one by one until **N** remain. Each removal improves the weakest **Objective** metric, keeping the selected set balanced.

| **Field**     | **Description**                                                             |
| ------------- | --------------------------------------------------------------------------- |
| **N**         | Number of records to keep.                                                  |
| **Objective** | Metrics to optimize: **E_Se=0, E_+P=1, D_Se=2, D_+P=3, D_Spec=4, D_NPV=5**. |
| **Ceil E_Se** | Optional upper cap for **E_Se** to prevent it from increasing too much.     |
| **Prefilter** | Removes records with any metric ≤ 0. Keep it enabled.                       |

The tool fields are shown below.

![](images/tool-hes-validation-image-025.png)

**Output:**

- **summary** — Selected count + 6 gross metrics.
- **epicmp_sumstats** — One row per selected record.
- **selected** — Hashes of selected records.

**Prefilter:** Removes records with any metric ≤ 0 or missing **D_Se** before selection. Keep it **on**.

Demo: **10 → 7** clean records. Real 701-AFIB pool: **701 → 575**.

![](images/tool-hes-validation-image-026.png)

**How greedy works:** Each round:

1. Review the 6 metrics of the kept records.
2. Find the weakest **Objective** metric.
3. Remove the record that gives the largest improvement to that metric.
4. Repeat until **N** records remain.

The **Objective** defines which metrics are considered. No weights are used.

**all6** — Watches all six metrics. In the demo, the weakest metric changes from **D_+P** (rounds 1–2) to **D_Se** (round 3).

![](images/tool-hes-validation-image-027.png)

**spec-npv** — Optimizes only **D_Spec** and **D_NPV**. It removes **LowSpec1**, then **LowSpec2**; once **D_Spec** improves, **D_NPV** becomes the weakest and **LowDSe1** is removed.

![](images/tool-hes-validation-image-028.png)

**sens** — Optimizes only **E_Se** and **D_Se**. Since **D_Se** is the weakest, it removes **LowDSe1** and keeps **LowSpec1/2** despite their low specificity. Final **D_Spec drops to 83.0**.

![](images/tool-hes-validation-image-029.png)

**Ceil E_Se** — Sets an upper limit for **E_Se** (e.g. **95.5**). Greedy skips removals that would increase E_Se above the cap, allowing Spec/NPV to improve without unnecessarily increasing E_Se.

The example below uses **demo_ceil.xlsx**.

![](images/tool-hes-validation-image-030.png)

### flag modes

**Flag mode** removes records that fail a fixed metric threshold, then recomputes the gross metrics of the remaining records. A **flagged** sheet lists the removed records for review.

Select the **Mode** and set the threshold; the greedy fields are disabled.

![](images/tool-hes-validation-image-031.png)

Five flag modes are available:

- **Low Q_Se / Q_+P** — Beat detection.
- **Low V_Se / V_+P** — Beat detection.
- **Low D_Se** — AFIB duration sensitivity.
- **Device miss/false AFIB** — AFIB detection errors.
- **AFIB all-zero** — AFIB metrics are all zero.

Example: **Low D_Se < 90** removes records below 90, then recalculates the remaining metrics.

![](images/tool-hes-validation-image-032.png)

## End-to-end: reproduce the finalised 300-AFIB set

![](images/tool-hes-validation-image-033.png)

## HR report tab

Average HR over AFIB episodes (**avg_hr = 60/mean(RR/250)**) + a **<60 / 60–120 / >120** bpm split.

**Run it** (markers 1-4):

1. **Download** the source folder **..\test-data\full-dataset\Tech\AFIB\FBD_true** (479 events) from the **full-dataset** on SharePoint (linked in the Dataset section above).

![](images/tool-hes-validation-image-034.png)

1. **Source folder** — the event folder to score (input).
2. **Verify (section)** — which annotation the HR is read from: **ai** or **tech** (here **tech**).
3. **Run**.
4. **Result** — 479 events; avg HR min 31.4 / mean 91.1 / max 216.2 bpm; bands **<60**=89, **60–120**=294, **>120**=96.
