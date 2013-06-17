Checkup
=======

This Applescript collects and displays hardware and configuration info. It was written for my particular environment then made generic for posting here. 

The script collects some system and hardware info, checks Munki software and config, CatalogURL for Apple software updates, and makes sure Kbox is running. All our Macs are supposed to be bound to Active Directory, and many are also bound to Open Directory, so it checks to make sure users can be id'ed from each directory. Most things are reported as OK or not OK, because I wanted it to help end users know when they shoudl call the help desk.
