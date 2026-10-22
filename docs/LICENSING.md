# 许可证建议：《具身递归自我改进》

> 调研日期：2026-10-22 · 适用仓库：`github.com/niuverse/niubook`
> 性质：基于公开资料的调研建议，不构成法律意见。正式发布前建议由熟悉中国、美国、欧盟版权与开源许可的律师审阅 NOTICE 与商业授权模板。

## 0. 结论（先看这里）

1. **内容许可：CC BY-NC-SA 4.0**，SPDX 标识符 `CC-BY-NC-SA-4.0`。
2. **代码/工具链：MIT**，SPDX 标识符 `MIT`；不要把 CC 许可用于软件。
3. **必须配 NOTICE**：写明 AI 生成部分不主张排他版权、第三方材料不在许可范围内、商业授权联系方式。
4. **纯 AI 生成部分在中/美/欧都可能不受版权保护**；能真正支撑“商业排他”的，是人类作者的选题、结构编排、编辑修改、注释、文献整理，以及由此形成的汇编/演绎作品。务必保留过程证据。
5. **不要选 CC BY 4.0 或 CC0**（等于放弃商业排他）；**也不建议全库 ARR**（学术复用太差）。若未来要签传统出版社的独家合同，需在公开发布前改选“ARR + 定制学术许可”，因为 CC 许可不可撤回。

## 1. 落地文件与 SPDX 写法

推荐仓库根目录：

```text
LICENSE                  # CC BY-NC-SA 4.0 完整法律文本（内容）
LICENSE-CODE             # MIT 文本（scripts/、toolchain/、模板代码）
NOTICE                   # 版权、AI 声明、第三方材料排除、商业授权
README.md                # 一句话许可声明 + 链接到 LICENSE / NOTICE
books/embodied-rsi/PROVENANCE.md   # AI 生成与人工审校溯源
```

`book.toml` 已写入：

```toml
[license]
spdx = "CC-BY-NC-SA-4.0"
name = "Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International"
url = "https://creativecommons.org/licenses/by-nc-sa/4.0/"
```

建议补充：

```toml
license_code = "MIT"
```

源文件头：

```typst
// SPDX-License-Identifier: CC-BY-NC-SA-4.0
```

```python
# SPDX-License-Identifier: MIT
```

`LICENSE` 文件建议放 CC 官方英文法律文本，不要改写；版权人、范围、AI 声明放在 `NOTICE`。这样 GitHub 的许可证识别也能正常工作。

## 2. README 一句话声明（中英各一句）

**中文：**

> 除另有说明外，本书内容采用 CC BY-NC-SA 4.0 许可（SPDX: CC-BY-NC-SA-4.0）：欢迎署名、非商业使用与相同方式共享；商业使用（含转售）须另行取得书面授权。

**English:**

> Except where otherwise noted, this book is licensed under CC BY-NC-SA 4.0 (SPDX: CC-BY-NC-SA-4.0); attribution, non-commercial use, and share-alike are permitted, while commercial use, including resale, requires separate written permission.

## 3. NOTICE 文本

### 3.1 中文版

```text
NOTICE / 权利与许可声明

版权 © 2026 Embodied RSI Research Group / Niubook。
本作品采用 CC BY-NC-SA 4.0 许可；未明确授予的权利均予保留。

一、许可范围
除另有说明外，本仓库中《具身递归自我改进：理论、系统与实践》的文字、图表、封面、版式、章节选择与编排、注释、导读、习题及文献整理，采用《知识共享 署名—非商业性使用—相同方式共享 4.0 国际许可协议》（CC BY-NC-SA 4.0）授权。
SPDX-License-Identifier: CC-BY-NC-SA-4.0
许可证全文：https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
构建脚本、Typst 模板等代码采用 MIT 许可，SPDX-License-Identifier: MIT。

二、商业使用
任何以商业优势或金钱报酬为主要目的或指向的使用，均不在 CC BY-NC-SA 4.0 授权范围内，包括但不限于：销售本书的纸质版或电子版；将本书用于付费课程、商业培训、付费数据库或订阅服务。上述使用须事先取得著作权人的书面商业授权。
联系：https://github.com/niuverse/niubook/issues

三、AI 生成内容
本书部分初稿由 Moonshot AI 的 Kimi K3 生成；人类作者完成了选题、大纲设计、多轮编辑、引用核验与统稿。依《Kimi 用户服务协议》第 5.2 条（本书生成时适用的版本见 PROVENANCE.md），用户在法律允许的范围内拥有输入与输出内容的知识产权；但依中国、美国、欧盟现行规则，完全由 AI 生成、缺乏人类实质性智力投入的部分可能不受著作权保护。
对于该等部分，作者不主张排他性著作权；如依任何法域认定其中存在可受保护的权利，作者同意在 CC BY-NC-SA 4.0 项下授权。对于人类作者的选题、结构编排、编辑修改、注释、文献整理等贡献，以及本书作为汇编/演绎作品的整体，作者在法律允许的范围内保留著作权所有权，并保留另行授予商业许可的权利。
作者不对任何 AI 输出的独创性、准确性、完整性或不侵权作出保证。

四、第三方材料
本书引用的他人文字、图表、数据、代码与文献，其权利仍归原权利人所有，不属于本许可证授权的范围。引用依适用法律的引用/合理使用规定或已取得许可。参考文献列表仅为引用信息，不构成对原作品的再许可。转载或改编本书时，应自行核实并清除第三方权利。

五、AI 标识
依《人工智能生成合成内容标识办法》（2025-09-01 施行）及 Kimi 协议，本书在封面、版权页与 README 中保留“AI 生成/辅助生成”说明。依该办法及适用法律，转载、改编或再分发时不得删除、篡改或隐匿依法添加的标识。

六、免责
本书按“现状”提供，不附带任何明示或默示担保，包括但不限于权利完整性、准确性、不侵权担保。CC BY-NC-SA 4.0 第 5 条的免责与责任限制条款适用。本 NOTICE 不构成法律意见；商业授权与侵权事宜请咨询执业律师。
```

### 3.2 English version

```text
NOTICE / Copyright and License Statement

Copyright © 2026 Embodied RSI Research Group / Niubook.
This Work is licensed under CC BY-NC-SA 4.0. All rights not expressly granted are reserved.

1. Scope of License
Except where otherwise noted, the text, figures, cover, layout, chapter selection and arrangement, annotations, and bibliography compilation of "Embodied Recursive Self-Improvement: Theory, Systems, and Practice" are licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0).
SPDX-License-Identifier: CC-BY-NC-SA-4.0
Full legal code: https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
Build scripts and Typst templates are licensed under the MIT License; SPDX-License-Identifier: MIT.

2. Commercial Use
Any use primarily intended for or directed towards commercial advantage or monetary compensation is outside the scope of the CC BY-NC-SA 4.0 grant, including, without limitation: sale of print or electronic copies; use in paid courses, commercial training, paid databases, or subscription services. Such use requires prior written commercial permission from the copyright holder.
Contact: [commercial licensing email] / https://github.com/niuverse/niubook/issues

3. AI-Generated Content
Parts of the draft were generated with Moonshot AI's Kimi K3; human authors carried out topic selection, outline design, multi-round editing, citation verification, and consolidation. Under the Kimi Terms of Service, s.5.2 (the version in force at the time of generation is recorded in PROVENANCE.md), users own the intellectual property rights in their input and output to the extent permitted by law. However, under current rules in China, the United States, and the European Union, material generated autonomously by AI without substantial human creative input may not be protected by copyright.
The authors make no exclusive copyright claim to such material. To the extent any such rights are recognized under any jurisdiction, the authors license them under CC BY-NC-SA 4.0. To the extent protected by law, the authors retain copyright ownership in their human contributions (topic selection, structure, editing, annotations, bibliography compilation) and in the compilation/derivative work as a whole, and reserve the right to grant commercial licenses.
No warranty is given as to the originality, accuracy, completeness, or non-infringement of any AI output.

4. Third-Party Material
Quotations, figures, data, code, and references from third parties remain the property of their respective rights holders and are not licensed under CC BY-NC-SA 4.0. They are used under applicable quotation/fair use provisions or with permission. The bibliography is provided for citation only and does not relicense any referenced work. Redistributors and adapters are responsible for clearing third-party rights.

5. AI Disclosure
Consistent with China's Measures for the Labeling of AI-Generated Synthetic Content (effective 1 September 2025) and the Kimi terms, the book carries an "AI-generated/assisted" notice on the cover, copyright page, and README. Under the Measures and applicable law, this notice must not be removed, altered, or concealed in any redistribution or adaptation.

6. Disclaimer
The Work is provided "as is", without warranties of any kind, express or implied, including warranties of title, accuracy, or non-infringement. The disclaimer and limitation of liability in Section 5 of CC BY-NC-SA 4.0 apply. This NOTICE is not legal advice; consult a qualified lawyer for commercial licensing and infringement matters.
```

## 4. 事实与依据

> 标记说明：**【原文】** = 直接抓取到的官方条款/法律文本；**【案例】** = 法院案例或官方典型案例；**【摘要】** = 官方文件的二手摘要/律所报道；**【推断】** = 基于以上材料的判断。

### 4.1 Moonshot AI / Kimi 的条款

**时效**：当前抓取到的是 **K3 时期**条款，不是 K2 旧版。Kimi 用户协议生效日期 **2026-08-31**（更新 2026-08-24）；开放平台中文协议同日生效；开放平台英文协议最后更新 **2026-07-30**。条款本身是模型无关的，适用于 Kimi 服务（页面标题已标 K3）。如果本书初稿生成于 2026-08-31 之前，当时适用的旧版条款可能不同；建议归档生成时的版本。**本次未核对 K2 旧版原文，因此不对旧版内容下结论。**

**【原文】Kimi 用户服务协议（中文）**
- 第 5.2 条：“在未侵害他人合法知识产权或其他权利并遵守本协议的前提下，您在法律允许的范围内，拥有对您输入和输出内容的知识产权、其他权利和对内容负责的义务。”并明确“您对输出所享有的权利无法当然及于其他用户的内容”。
- 第 5.3 条：“为了提升您使用本服务的体验，您授予我们一项免费的使用权，以在法律允许的范围内将您输入输出之内容及反馈用于模型服务优化。”如不希望被用于训练，可通过协议联系方式提出。
- 第 1.3 条：“使用场景：本服务适用于个人学习、研究、欣赏、日常生活及娱乐使用。”
- 第 6.3 条：不得以任何方式移除、遮挡、篡改、隐藏或规避服务默认添加的显式/隐式 AI 标识。
- URL：https://www.kimi.com/user/agreement/modelUse?version=v2

**【原文】Kimi Terms of Services（英文）**
- s.5.2：用户在法律允许的范围内拥有 Input/Output 的知识产权；但输出可能与其他用户雷同，权利不及于他人内容。
- s.5.3：用户授予 Moonshot 免费许可，将 Input/Output/Feedback 用于模型优化；可联系退出。
- s.1.3：服务用于个人学习、研究、欣赏、日常生活与娱乐。
- s.6.3：不得移除/篡改 AI 标识。
- URL：https://www.kimi.com/user/agreement/en/modelUse?version=v2

**【原文】Kimi 开放平台服务协议（中文）**
- 第 6.2 条：与用户协议 5.2 相同的归属表述（“在法律允许的范围内”拥有输入输出知识产权）。
- 第 6.3 条：同样的模型优化免费许可。
- 第 3.1 条：服务“仅供您内部使用或向最终用户提供服务”；“您利用本服务的输出对外提供产品或服务时，应当严格遵守各项法律法规，取得合法经营资质和政府审批……”。
- URL：https://platform.kimi.com/docs/agreement/modeluse

**【原文】Kimi OpenPlatform Terms of Service（英文）**
- Section 4：“You are solely responsible for content and we do not claim ownership of it.”
- Section 7：Moonshot 对 Services（软件、模型、界面等）享有全部权利。
- Section 3.2(6)：不得未经授权复制、转让、出租、出售或分许可 **Services**（注意：限制对象是服务，不是 Output）。
- 管辖：新加坡法、SIAC 仲裁。
- URL：https://platform.kimi.ai/docs/agreement/modeluse.md

**【推断】**
- 条款没有发现“禁止再分发输出”的明文；限制的是 Kimi 服务本身（账号、API、模型、界面）的复制/转售/分许可。
- “在法律允许的范围内”是关键限定：协议承认用户对输出享有权利，但**不能创造法律上不存在的著作权**；纯 AI 输出是否受保护，仍由著作权法决定。
- 消费端条款把使用场景描述为“个人学习、研究、欣赏、日常生活及娱乐”，没有明确允许商业出版；若本书未来要商业化，优先使用开放平台/付费 API，并保留合同与发票。开放平台条款明确面向“开发者……面向组织内部或终端用户的产品及服务”，更适配出版。
- 第 5.3/6.3 条的“免费许可用于模型优化”不影响所有权，但意味着输入输出可能被用于训练；如不希望，按协议联系 Moonshot。

### 4.2 中国

**【原文】《中华人民共和国著作权法》**
- 第 3 条：作品是“文学、艺术和科学领域内具有独创性并能以一定形式表现的智力成果”。
- 第 11 条：“创作作品的自然人是作者”；法人/非法人组织在特定条件下视为作者。
- 第 13 条：改编、翻译、注释、整理已有作品而产生的作品，著作权由改编、翻译、注释、整理人享有，但不得侵犯原作品著作权。
- 第 15 条：汇编若干作品、作品片段或者不构成作品的数据/其他材料，对其内容的选择或者编排体现独创性的作品，为汇编作品，著作权由汇编人享有。
- 第 24 条：个人学习研究、适当引用、学校课堂教学/科研（不得出版发行）等合理使用情形。
- URL：https://www.gov.cn/guoqing/2021-10/29/content_5647633.htm

**【案例】2023 年北京互联网法院“AI 文生图”第一案**
- 案号：(2023)京0491民初11279号。
- 法院认定：原告设计人物呈现、选择提示词并安排顺序、设置参数、反复修改调整，体现了智力投入和个性化表达；AI 模型不能成为作者，原告是作者，享有著作权。
- URL：https://english.bjinternetcourt.gov.cn/2024-02/28/c_695.htm

**【案例】2025 年北京互联网法院 AI 生成图片（举证失败）**
- 案号：(2024)京0491民初10423号；二审 (2025)京73民终360号。
- 原告无法提交原始提示词、参数、生成/筛选/修改记录（账号被禁用），仅做“事后复现”；法院认为不足以证明独创性，驳回全部诉讼请求。
- 裁判要点：主张 AI 生成物构成作品者，应说明创作思路、输入指令、选择与修改过程并提交证据；作品登记证书只是权属初步证据，不能当然证明独创性；“事后复现”不能替代原始创作过程记录。
- URL：https://www.ciplawyer.cn/articles/159209.html

**【案例】2025 年度“认定 AI 生成图片不具备独创性”案**
- 江西鹰潭月湖区法院，入选最高人民法院“新时代推动法治进程 2025 年度十大提名案件”。
- 原告仅输入一次抽象场景提示词，完全依赖模型自动生成，未体现参数调整、选择与修改；法院认定 AI 主导性过高，缺少人类创作控制力和个性化表达，不构成作品。
- URL：https://finance.sina.com.cn/wm/2026-03-20/doc-inhrqtyz8199040.shtml

**【原文】最高人民法院《关于依法审理涉人工智能纠纷案件的意见》**
- 法发〔2026〕10 号，2026-09-07 发布，首部由最高审判机关发布的涉 AI 司法裁判规则文件，5 部分 24 条。
- 第（十六）条明确：对于构成汇编作品或者符合其他作品构成要件的数据、数据集合，依照著作权法保护。
- 但《意见》**没有**对“AI 生成内容本身是否构成作品”作出明确规则；发布会说明对目前难以形成共识的问题“做了留白处理”。因此仍要回到个案与现有著作权法。
- 发布会同时明确：我国尚未出台专门的人工智能法；《意见》依据民法典、著作权法等现行法律制定；“十五五”规划提出探索 AI 生成物权利归属规则（政策，不是现行法）。
- URL：https://ipc.court.gov.cn/zh-cn/news/view-6033.html

**【原文】《人工智能生成合成内容标识办法》**
- 国信办通字〔2025〕2 号，2025-09-01 施行。
- 第 4 条：服务提供者对 AI 生成的文本、图片、音频、视频等添加显式标识；第 5 条：文件元数据添加隐式标识；第 10 条：用户通过传播服务发布 AI 生成内容，应主动声明并使用标识功能；任何组织和个人不得恶意删除、篡改、伪造、隐匿标识。
- URL：https://www.cac.gov.cn/2025-03/14/c_1743654684782215.htm

**【推断】**
- 纯 AI 生成的中文教材正文，在中国法下**很可能不构成作品**；2023 年案是“人类实质智力投入”的高水位，2025 年两案明显收紧，2026 年最高法意见仍未给 AI 输出“确权”。
- 人类作者的**选题、章节结构、内容选择与编排、编辑修改、注释、文献整理**，可以尝试主张**汇编作品**（著作权法第 15 条）或**演绎作品**（第 13 条）保护；但“编排”必须有独创性，且要能证明。
- 仅做错别字、格式、事实性修正，通常不足以形成独创性表达；越接近“重写、重构、原创注释/导读”，越可能受保护。
- 书名本身通常不受著作权保护；如要防止他人用同名卖书，需考虑商标/不正当竞争，而不是版权。

### 4.3 美国

**【原文】U.S. Copyright Office, Copyright Registration Guidance（2023-03-16，88 FR 16190）**
- 版权只保护人类创作；AI 自主生成的材料不受保护。
- 仅提供 prompt，通常不足以使输出成为人类作品；“prompts function more like instructions to a commissioned artist”。
- 人类对 AI 生成材料进行**创造性选择、编排**，或修改到足够程度，可以就“人类贡献部分”获得保护；AI 生成材料本身仍不受保护。
- 申请人有义务**披露**作品中包含 AI 生成内容，并说明人类贡献；超过 de minimis 的 AI 材料应在申请中排除。
- URL：https://www.govinfo.gov/content/pkg/FR-2023-03-16/html/2023-05321.htm

**【原文】U.S. Copyright Office, Part 2: Copyrightability（2025-01-29）**
- 生成式 AI 输出只有在人类作者确定了足够表达要素时才受保护；可以是人类作品在输出中可感知，或人类对输出进行创造性编排/修改，但**不能只是提供 prompt**。
- 使用 AI 辅助创作、或把 AI 生成材料纳入更大的人类作品，不当然妨碍版权；但保护范围只及于人类贡献。
- 版权局认为现有法律足够灵活，不需要为 AI 输出另设新权利。
- URL：https://www.copyright.gov/newsnet/2025/1060.html

**【原文】Part 3: Generative AI Training（2025-05-09 预发布）**
- 处理训练数据/合理使用与责任分配，不直接回答“输出是否可版权”；最终版尚未发布（以版权局 AI 页面为准）。
- URL：https://www.copyright.gov/ai/

**【摘要】Thaler v. Perlmutter / 美国最高法院**
- 哥伦比亚特区巡回法院 2025 年维持“美国版权法要求人类作者”的裁决；2026-03-02 美国最高法院拒绝调卷（denied certiorari），人类作者要求保持不变。
- URL（律所报道，非判决原文）：https://webiis08.mondaq.com/unitedstates/copyright/1756930/supreme-court-declines-to-hear-thaler-v-perlmutter-leaving-human-authorship-requirement-intact

**【推断】**
- 纯 AI 生成部分在美国**不受版权保护**；人类的选择、编排、编辑、注释可以构成可保护的汇编/演绎贡献，但必须在登记时披露并排除 AI 材料。
- 如果未来在美国登记，申请表中应把 AI 生成部分列入 “Material Excluded”，人类贡献列入 “Author Created”；否则可能影响登记效力。

### 4.4 欧盟

**【原文】EU AI Act（Regulation (EU) 2024/1689）**
- 第 53(1)(c) 条：通用人工智能模型提供者应制定版权合规政策，识别并遵守依《DSM 指令》第 4(3) 条作出的权利保留（opt-out）。这是**训练数据**侧义务，不是输出确权。
- 第 50 条：生成合成内容的 AI 系统提供者，应确保输出以机器可读方式标记为 AI 生成/操纵；部署者亦负有相应的披露义务。这是**透明度**义务，不是著作权归属规则。
- 条文镜像（非官方，但与 Regulation (EU) 2024/1689 一致）：https://artificialintelligenceact.eu/article/53/ ；https://artificialintelligenceact.eu/article/50/

**【摘要】欧洲议会 2026-03-10 版权与生成式 AI 决议**
- 决议编号 2025/2058(INI)，以 460 票赞成、71 票反对、88 票弃权通过。
- 明确：完全由 AI 生成、不符合既定版权保护要件的内容，应继续**不具备版权保护资格**；其公有领域地位应被明确。
- 同时呼吁对训练数据授权、透明度和公平报酬立法。
- URL（European Audiovisual Observatory 摘要）：https://merlin.obs.coe.int/article/10499

**【推断】**
- 欧盟没有统一的“AI 生成物作者”规则；AI Act 不创设版权，只监管模型提供者与透明度。是否保护、保护谁，仍由各成员国依人类作者标准审理。
- 完全 AI 生成的部分在欧盟很可能不受保护；人类选择/编排在部分成员国可能受版权或数据库权保护，但不确定。
- 如果书在欧盟销售，AI 标识/透明度是加分项；但 AI Act 第 50 条的直接义务主体是 AI 系统提供者/部署者，不是本书作者。本书主动标注仍是合规与伦理上的稳妥做法。

### 4.5 CC 许可

**【原文】CC BY 4.0**
- 允许共享、改编，包括商业目的；要求署名、附许可证链接、注明修改；不得增加额外限制。
- URL：https://creativecommons.org/licenses/by/4.0/

**【原文】CC BY-NC-SA 4.0**
- 只允许非商业目的；要求署名；改编作品须以相同许可证（或兼容许可证）共享。
- “NonCommercial”定义：“not primarily intended for or directed towards commercial advantage or monetary compensation.”
- 许可只覆盖许可人**有权许可**的版权及类似权利；不覆盖商标、专利；不覆盖许可人没有的权利。
- 第 2(a)(5)(C) 条禁止附加限制；第 5 条 disclaimer of warranties。
- URL：https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en

**【原文】CC0 1.0**
- 在最大范围内放弃版权及相关权利；如放弃无效，则回退为无条件、非排他、不可撤销的许可；允许商业使用，不要求署名。
- URL：https://creativecommons.org/publicdomain/zero/1.0/legalcode.en

**【原文】Creative Commons, Guidance on CC Licensing in the Age of AI（2026-09）**
- CC 许可首先是**版权工具**：只在版权适用的范围内传达许可。
- AI 的许多使用可能落在版权之外（例外/限制），许可无法覆盖；更严格的许可可能限制人类复用，却不能阻止 AI 使用。
- 许可人应清楚标记**不受许可覆盖**的材料（第三方材料、例外/限制下的材料）。
- URL：https://creativecommons.org/cc-license-guidance/ ；https://creativecommons.org/2026/09/03/guidance-on-using-cc-licenses-in-an-ai-ecosystem/

**【推断】**
- 把 CC BY-NC-SA 4.0 用于整本书是可行的：它只作用于你有权许可的部分；纯 AI 文本若不受保护，许可对它没有实际约束力，但也不会因此“制造”出权利。
- 因此 NOTICE 必须诚实说明“AI 部分不主张排他版权”，否则可能构成过度主张。
- CC 许可不能阻止：非商业镜像/转载、合理使用、以及许多 AI 训练用途。若这些是核心顾虑，CC 不是合适工具，应考虑 ARR + 合同/技术措施，但执行仍困难。

## 5. 四者对比

| 许可证 | 允许商业使用 | 要求署名 | 要求相同方式共享 | 适用性 |
|---|---|---|---|---|
| **CC BY 4.0** | 是 | 是 | 否 | 传播最广、学术最友好，但允许他人商用、转售、做付费版；**不符合“保留商业排他/不希望别人拿去卖”** |
| **CC BY-NC-SA 4.0** | 否（非商业）；作者可另行商业授权 | 是 | 是（改编作品须同许可） | **最匹配**：学术非商业使用友好、禁止转售、改编须保持非商业；作者保留商业许可权。缺点：NC 边界模糊、执行成本高、不是 OSI 意义上的“开源” |
| **CC0 1.0** | 是 | 否 | 否 | 公有领域、最大自由；**放弃全部排他性**，不适合本书正文；只适合你确定不主张权利的数据/元数据 |
| **All rights reserved** | 否（默认）；需逐案许可 | 无许可要求，但仍受署名权等精神权利约束（视法域） | 否 | 控制最强，但学术复用差（翻译、改编、课堂汇编都要许可）；可配“定制学术许可”；适合未来签独家出版合同 |

> 注：你要求“4 列”，但列了 5 项；上表按 5 列呈现。

## 6. 执行清单

1. **加 `LICENSE`**：CC BY-NC-SA 4.0 官方英文法律文本，不改写。
2. **加 `LICENSE-CODE`**：MIT 文本；`scripts/`、`toolchain/`、Typst 模板代码适用。
3. **加 `NOTICE`**：用上面的中英文模板；商业授权联系入口统一使用仓库 Issues。
4. **改 `README.md`**：加中英一句话声明 + 链接到 `LICENSE` / `NOTICE`。
5. **加 SPDX 头**：章节 `.typ` 用 `CC-BY-NC-SA-4.0`；Python/脚本用 `MIT`。
6. **写 `PROVENANCE.md`**：模型名/版本、生成日期、关键 prompt 或 prompt 摘要、章节生成顺序、人工编辑与引用核验记录、哪些章节含 AI 生成内容。仓库 `book.toml` 已有 `generator = "Kimi K3"`，把它展开成可审计的记录。
7. **加 AI 标识**：封面/版权页/README 写“本作品包含 AI 生成内容；由 Kimi K3 辅助生成，人类作者完成选题、大纲、编辑、引用核验与统稿”。不要删除 Kimi 界面/文件中的 AI 标识。
8. **核验 24 条 `UNVERIFIED` 文献**：`book.toml` 记录 `unverified = 24`；发布前逐条核实，避免 AI 幻觉引用。
9. **检查第三方图表/引文**：CC 许可不覆盖第三方材料；需要时取得许可或在 NOTICE 中排除。
10. **决定贡献政策**：如接受 PR，要求贡献者签署 CLA（授予你商业再许可权），或声明“仅接受邀请贡献”；否则社区贡献会让未来商业授权复杂化。
11. **考虑中国作品登记**：对“人类贡献 + 汇编”做自愿登记，保留创作/编辑过程记录；登记证书不是独创性的充分证明，证据链更重要。
12. **归档 Kimi 条款**：把 2026-08-31 版协议 PDF/截图存档；如果生成时间早于该版本，找当时的版本。
13. **不要加 DRM/额外限制**：CC BY-NC-SA 禁止附加限制；给 PDF 加 DRM 或“禁止转载”EULA 会与 CC 冲突。要强控制就走 ARR。
14. **未来独家出版**：CC 许可不可撤回；如要签传统出版社的独家合同，最好在公开发布前决定是否改用 ARR + 定制学术许可。

## 7. 不确定性与风险

1. **AI 可版权性本身不确定**：中国个案差异大，美国要求人类作者，欧盟无统一规则；本书纯 AI 正文很可能不受保护，汇编/演绎主张是“可能”，不是“保证”。
2. **“商业排他”不是版权自动保证**：版权只禁止他人复制表达，不禁止独立创作、思想/事实使用、相似 AI 输出；Kimi 协议也明确不能保证输出不与其他人雷同。
3. **NC 边界模糊**：什么叫“主要指向商业优势”因法域/事实而异；大学出版社、付费培训、企业内训是否商业使用，可能争议。执行成本高。
4. **公开 GitHub + CC = 不可撤回**：一旦发布，他人可非商业转载/镜像；你无法“收回”已发布的 CC 版本。若未来要独家出版，这是实质性障碍。
5. **NC 不阻止 AI 训练**：CC 官方 2026 指南明确，许多 AI 使用可能落在版权之外；因此不能假定 CC BY-NC-SA 能阻止模型训练/检索增强使用（推断）。若这是核心顾虑，CC 不是合适工具。
6. **第三方材料风险**：327 条参考文献中 24 条待核实；图表/长引文可能涉及第三方权利；CC 许可不覆盖这些材料。
7. **AI 输出侵权风险**：模型可能复现训练数据中的受保护表达；Moonshot 条款不保证不侵权，且用户通常承担输出使用责任。发布前做相似度/查重与人工审阅。
8. **中国出版合规**：在中国大陆正式出版/销售纸质书通常需要具备资质的出版单位/ISBN；免费 PDF 属于网络传播，仍需内容与 AI 标识合规。这不是许可证能解决的问题。
9. **贡献者权利**：公开仓库的 PR/改编若没有 CLA，未来商业授权可能受限。
10. **标题/品牌**：著作权通常不保护书名；要防止同名销售，需商标/反不正当竞争，另做布局。
11. **本调研不是法律意见**：正式发布前请律师审阅 NOTICE、商业授权模板与第三方材料清单。

## 8. 主要来源（均为本次实际抓取）

**Kimi / Moonshot**
- https://www.kimi.com/user/agreement/modelUse?version=v2
- https://www.kimi.com/user/agreement/en/modelUse?version=v2
- https://platform.kimi.com/docs/agreement/modeluse
- https://platform.kimi.ai/docs/agreement/modeluse.md

**中国**
- https://www.gov.cn/guoqing/2021-10/29/content_5647633.htm
- https://english.bjinternetcourt.gov.cn/2024-02/28/c_695.htm
- https://www.ciplawyer.cn/articles/159209.html
- https://finance.sina.com.cn/wm/2026-03-20/doc-inhrqtyz8199040.shtml
- https://ipc.court.gov.cn/zh-cn/news/view-6033.html
- https://www.cac.gov.cn/2025-03/14/c_1743654684782215.htm

**美国**
- https://www.govinfo.gov/content/pkg/FR-2023-03-16/html/2023-05321.htm
- https://www.copyright.gov/newsnet/2025/1060.html
- https://www.copyright.gov/ai/
- https://webiis08.mondaq.com/unitedstates/copyright/1756930/supreme-court-declines-to-hear-thaler-v-perlmutter-leaving-human-authorship-requirement-intact

**欧盟**
- https://artificialintelligenceact.eu/article/53/
- https://artificialintelligenceact.eu/article/50/
- https://merlin.obs.coe.int/article/10499

**CC**
- https://creativecommons.org/licenses/by/4.0/
- https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en
- https://creativecommons.org/publicdomain/zero/1.0/legalcode.en
- https://creativecommons.org/cc-license-guidance/
- https://creativecommons.org/2026/09/03/guidance-on-using-cc-licenses-in-an-ai-ecosystem/
- https://zenodo.org/records/22261032
