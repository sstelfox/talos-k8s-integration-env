# Repo Secret Management

This document covers the reasoning behind and the path forward for the choice of in-repo secret
protection. There exists private key material that is tied heavily to a specific
deployment/environment/instance and its worth keeping that as close to where its managed to allow
for automated processes and systems to also be kept up to date. The trade off being made is that
these tend to be VERY sensitive values, mostly comprising of root level or administrative ownership
over the cluster. These secrets MUST be encrypted and done so well.

The scope of these secrets is only those required during the initial bootstrap (and during disaster
recovery) of a cluster to get it to an operational state. Service specific data, accounts, and
configuration are outside the scope of this document though some initial values and secondary keys
(such as those protecting the backups themselves) may be worth supporting with the chosen tool.

Once a cluster has been bootstrapped, authentication material that needs to be protected should make
use of Vault for secret and credential storage and management. There is a small overlap in that the
Vault backups will need to make use of a key that is available before Vault itself is brought up
during DR scenarios, this solution SHOULD cover the use-case of protecting the backup keys.

## Requirements

* Encrypted with current best practice algorithms
* Able to operate in an air-gapped / fully offline environment
* Must allow for multiple independent keys to access protected information
* Must allow for automations to be used as this will be validated regularly in an integration environment
* Must support auditing of credential access and rotation
  * Must be able to identify who had access at a specific point in time
  * Must be able to identify how old a specific credential is, when it has been changed, and by who
* Prefer this to have low-management overhead
* Prefer this to work with standard git-ops tools
* Prefer native integration with ArgoCD to take over the maintenance and management of the secrets
  once the cluster is up.
  * This likely requires support similar to Vault in that ArgoCD is intended to be "up" before Vault
    is available and populated
* Must protect all key material and secrets desired to be stored in this repo some of which may not
  be format specific (a tool that only works on helm values file probably won't cut it for storing a
  local backup key).
* Asymmetric crypto is required, this allows processes where one side can encrypt data (such as for
  backup by another process) without getting access to all backups or older versions of the backups
  once encrypted. This also provides a strong audit property of identifying who the author even when
  the content is decryptable by others.We do have to consider the possibilities of FIPS requirements
  not only for the environment but for tooling around the environment which might restrict which
  algorithms can be selected for this protection and may degrade the desired security.
* Root of trust in a physical hardware token is preferred, YubiKey, CCID/PIV card, TPM, or FIDO2 are
  options that meet this requirement (there are others but these are the relevant ones for our
  solution survey).

## Solution Survey

When this position document was written active practitioners were consulted, and recent trends in
best practices and preferred tools were referenced to come up with the pieces of software that could
help solve this problem. At the time of this decision the tools currently in use for protection of
this kind of information primarily fall to the following pieces of software:

* **GPG/PGP:** GnuPG is a complete and free implementation of the OpenPGP standard as defined by
  RFC4880 (also known as PGP). GnuPG allows you to encrypt and sign your data and communications.
* **git-crypt:** enables transparent encryption and decryption of files in a git repository.
* **AGE:** a simple, modern and secure file encryption tool, format, and Go library.
* **SOPS:** SOPS is an editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY
  formats and encrypts with AWS KMS, GCP KMS, Azure Key Vault, age, and PGP.

### GPG/PGP

Designed primarily for asymmetric arbitrary data exchange along a pre-existing web-of-trust. Works
offline and asynchronously but is hard to use, automate, and integrate. PGP is included in this item
but does not meet the requirements of the project and will not be considered. Most likely outcome
involves using a tool that builds upon GPG if its used at all rather than doing so directly. May
provide accessibility and compatibility headaches across systems.

The only way to meet the hardware security requirements with this one is to use a CCID card or a
YubiKey in CCID mode. This specifically is one of the most painful management experiences that will
cause on-going headaches for people using this software as the CCID integrations, protocols, and
shell agents are _inconsistent_, _poorly maintained_, and _unreliable_.

### git-crypt

Built primarily on-top of GPG, this integrates really well with git and works with any file checked
in. This can happen automatically using git operation filters and is generally used pretty widely.
The big downside with this project is it effectively leaves the secrets unencrypted on the machines
where the data is checked out and have access to it. This can be solved by process but relies on
human memory and in-grained behavior.

Operationally in the past this path forward needs automation assistance from tools like git-leaks
to detect accidental commits of sensitive data, and that isn't able to perfectly detect these
issues. Those tools do not address the problem of leaving the content "unlocked" on user machines
without expiration until a manual action is taken. Keeping the protected content unencrypted at
rest, even on devices that are well protected fails to meet our control requirements.

Since this does build on GPG, and symmetric keys are not a flexible enough option, it has the same
hard pain points for physical roots of trust.

### AGE

This tool is more generic than the other ones, its kept simple and primarily handles asymmetric
encryption of specific files. Multiple potential identities available can be referenced allowing
multiple members of a team to get access to encrypted information but there is no automation or
handling of the secrets or content beyond encrypt/decrypt.

This can meet the hardware controls by integrating with a TPM, FIDO2, PIV/CCID card, or a YubiKey
through plugins. Preliminary testing before a decision was made validated the use of FIDO2, and
YubiKey in CCID as working options. The CCID mode has the same integration and management issues as
GPG. The quality of the encryption is high and this is a very easy to use and script-able tool.

Taking this path would be choosing to write a fair number of supporting scripts and tools around it
to meet the desired functionality and reasonably staying out of the way of the systems use.

#### SSH Key Reuse

AGE has an interesting feature that others don't support, which is the use of SSH keys as encryption
keys. We're already using FIDO2 keys for our central authentication second-factor, and using them
for SSH access to our repository forge. It is unclear and untested if we could migrate our git
commit signing, and the encryption of these secrets using this tool. Pursuing this path may allow
for better tracking of SSH & Git signing keys binding them tighter together while still meeting our
goals.

Allowing the use of an SSH key for this purpose will open up the ability of non-hardware backed
keys to be used. This may be acceptable to leave as an organization/policy control but should be
considered further.

One of the concerns that has been noted about FIDO2 backed decryption is that it may require
constant verification. This can probably be avoided, but use with a SSH key may allow agent
cacheing of the credentials to reduce verification down to at most once every five minutes (refer
to: Workstation Security Policy -> Credential Cacheing for this value).

### SOPS

SOPS is more of an encryption management tool with a heavy focus on protecting YAML/JSON files as
part of a git-ops process. It allows you to define repo-wide paths and patterns that should be
protected with different keys or sets of keys which makes it significantly easier to work with.
This does support GPG, but as discussed in other sections this is not a preferred path forward.
SOPS also works with AGE directly, but does not support the use of any plugins which are required
to provide physical hardware support.

There is a potential path forward here using a hybrid of AGE w/ physical device and asymmetric
crypto managing and decrypting a shared secret to memory that is then used by SOPS as a "human" key.
This solution looses a bit of audit-ability as signatures of protected secrets will always map to
the shared in-memory key instead of specific user keys. This is less of an issue with commit
signing, but those signatures are not performed over the content on hashes of the content via a
separate data structure and uses a deprecated hash algorithm (SHA1) which is believed to be too weak
for new use.

## Decision

After looking through the options we're going to move forward with a hybrid approach of SOPS & AGE.
Specifically:

* Each user will have their own AGE key backed by a hardware device
  * Identities for each user's keys will be included in the repo
  * We'll use age directly with [age-plugin-fido2-hmac](https://github.com/olastor/age-plugin-fido2-hmac/)
    to interact with FIDO2 devices directly
  * We'll explore the feasibility and trade-offs of SSH key (backed by FIDO2) as a possible
    alternative.
* User private keys will be used to decrypt an appropriate shared key
  * There needs to be a different shared key for different levels of access
    * AppEng: For private applications running on the cluster that are managed by less privileged
      users, this group only has access to non-infrastructure manifest secrets.
    * Operations: Needs access to secrets existing in all manifests. The users primarily manage
      infrastructure manifests but support application engineers.
    * Root: Break-glass admin credentials, roots of trust, and service private keys. These are used
      during cluster initialization and disaster recovery. This key does not need access to any
      manifests, a user performing these tasks is expected to be operations staff and should be
      able to use their normal privileges (and the scripts around them) with those credentials.
  * Each key will be stored encrypted in the repository itself
  * These will only exist decrypted in memory and will not be written to disk in an unencrypted form
* Other tools such as those required for backups and the CI/CD process will have their own key
  * ArgoCD: Service key used to update secrets managed in this repository and as such needs
    access to secrets in all the manifests.
  * Backup Key: Key used to encrypt data backups from the cluster. Rotated every 30 days. Public
    portion is injected as a configuration into the cluster. Does not encrypt anything within the
    repository.
  * These keys will be protected with a human key in the repo with the most restrictive access
* SOPS will be used to manage the encryption of general secrets within the repo
  * Helper wrapper will be used to decrypt the appropriate shared key and provide it to SOPS via the
    SOPS_AGE_KEY environment variable
