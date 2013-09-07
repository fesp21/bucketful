sinon = require 'sinon'
fs = require 'fs'
_ = require 'underscore'
should = require 'should'
jscov = require 'jscov'
deploy = require jscov.cover('..', 'src', 'deploy')
stringstream = require './util/stringstream'

describe 'deploy', ->

  override = (original, cb) ->
    (args...) -> cb.apply(this, [original].concat(args))

  beforeEach ->

    popOne = (method, argumentsObject) =>
      syncMethods = ['createAws']
      args = _.toArray(argumentsObject)
      next = @expects?.shift()

      if next
        method.should.eql next.method

        if method in syncMethods
          args.should.eql next.args
        else
          args.slice(0, -1).should.eql next.args
          args.slice(-1)[0].should.be.a('function')

    @listBuckets = (opts, callback) ->
      popOne('listBuckets', arguments)
      callback(null, { Buckets: [] })

    @createBucket = (opts, callback) ->
      popOne('createBucket', arguments)
      callback()

    @putBucketWebsite = (opts, callback) ->
      popOne('putBucketWebsite', arguments)
      callback()

    @getBucketAcl = (opts, callback) ->
      popOne('getBucketAcl', arguments)
      callback(null, {
        Grants: []
        Owner: {}
      })

    @putBucketAcl = (opts, callback) ->
      popOne('putBucketAcl', arguments)
      callback()

    @putObject = (opts, callback) ->
      popOne('putObject', arguments)
      callback()

    @mockAws = () =>
      popOne('createAws', arguments)
      { @listBuckets, @createBucket, @putBucketWebsite, @getBucketAcl, @putBucketAcl, @putObject }

    @mockDns = {
      setCNAME: (bucket, cname, callback) ->
        popOne('setCNAME', arguments)
        callback()
    }





  it 'runs properly given a sane set of arguments', (done) ->

    @expects = [
      method: 'createAws'
      args: [
        region: 'eu-west-1'
        key: 'awskey'
        secret: 'awssecret'
      ]
    ,
      method: 'listBuckets'
      args: [{}]
    ,
      method: 'createBucket'
      args: [
        Bucket: 'mybucket.leanmachine.se'
      ]
    ,
      method: 'putBucketWebsite'
      args: [
        Bucket: 'mybucket.leanmachine.se'
        WebsiteConfiguration:
          IndexDocument:
            Suffix: 'index.html'
          ErrorDocument:
            Key : 'error.html'
      ]
    ,
      method: 'getBucketAcl'
      args: [
        Bucket: 'mybucket.leanmachine.se'
      ]
    ,
      method: 'putBucketAcl'
      args: [
        Bucket: 'mybucket.leanmachine.se'
        AccessControlPolicy:
          Owner: {}
          Grants: [
            Permission: 'READ'
            Grantee:
              URI: 'http://acs.amazonaws.com/groups/global/AllUsers'
              Type: 'Group'
          ]
      ]
    ,
      method: 'setCNAME'
      args: ['mybucket.leanmachine.se', 'mybucket.leanmachine.se.s3-website-eu-west-1.amazonaws.com']
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'text/plain'
        Key: 'file.txt'
        Body: fs.readFileSync('./spec/data/file.txt')
      ]
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'application/octet-stream'
        Key: 'other.coffee'
        Body: fs.readFileSync('./spec/data/other.coffee')
      ]
    ]

    deploy
      s3bucket: 'mybucket.leanmachine.se'
      aws_key: 'awskey'
      aws_secret: 'awssecret'
      aws_user: 'myawsuser'
      region: 'eu-west-1'
      siteIndex: 'index.html'
      siteError: 'error.html'
      targetDir: 'spec/data'
      dnsProvider: @mockDns
      createAwsClient: @mockAws
    , (err) =>
      should.not.exist err
      @expects.should.have.length 0
      done()





  it 'simply ignores setting the cname if no provider is given', (done) ->

    @expects = [
      method: 'createAws'
      args: [
        region: 'eu-west-1'
        key: 'awskey'
        secret: 'awssecret'
      ]
    ,
      method: 'listBuckets'
      args: [{}]
    ,
      method: 'createBucket'
      args: [
        Bucket: 'mybucket.leanmachine.se'
      ]
    ,
      method: 'putBucketWebsite'
      args: [
        Bucket: 'mybucket.leanmachine.se'
        WebsiteConfiguration:
          IndexDocument:
            Suffix: 'index.html'
          ErrorDocument:
            Key : 'error.html'
      ]
    ,
      method: 'getBucketAcl'
      args: [
        Bucket: 'mybucket.leanmachine.se'
      ]
    ,
      method: 'putBucketAcl'
      args: [
        Bucket: 'mybucket.leanmachine.se'
        AccessControlPolicy:
          Owner: {}
          Grants: [
            Permission: 'READ'
            Grantee:
              URI: 'http://acs.amazonaws.com/groups/global/AllUsers'
              Type: 'Group'
          ]
      ]
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'text/plain'
        Key: 'file.txt'
        Body: fs.readFileSync('./spec/data/file.txt')
      ]
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'application/octet-stream'
        Key: 'other.coffee'
        Body: fs.readFileSync('./spec/data/other.coffee')
      ]
    ]

    deploy
      s3bucket: 'mybucket.leanmachine.se'
      aws_key: 'awskey'
      aws_secret: 'awssecret'
      aws_user: 'myawsuser'
      region: 'eu-west-1'
      siteIndex: 'index.html'
      siteError: 'error.html'
      targetDir: 'spec/data'
      createAwsClient: @mockAws
    , (err) =>
      should.not.exist err
      @expects.should.have.length 0
      done()




  it 'does not attempt to create a new bucket if it already exists', (done) ->

    @expects = [
      method: 'createAws'
      args: [
        region: 'eu-west-1'
        key: 'awskey'
        secret: 'awssecret'
      ]
    ,
      method: 'listBuckets'
      args: [{}]
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'text/plain'
        Key: 'file.txt'
        Body: fs.readFileSync('./spec/data/file.txt')
      ]
    ,
      method: 'putObject'
      args: [
        ACL: 'public-read'
        Bucket: 'mybucket.leanmachine.se'
        ContentType: 'application/octet-stream'
        Key: 'other.coffee'
        Body: fs.readFileSync('./spec/data/other.coffee')
      ]
    ]

    @listBuckets = override @listBuckets, (base, opts, callback) =>
      base opts, ->
        callback(null, { Buckets: [{ Name: 'mybucket.leanmachine.se' }] })

    deploy
      s3bucket: 'mybucket.leanmachine.se'
      aws_key: 'awskey'
      aws_secret: 'awssecret'
      aws_user: 'myawsuser'
      region: 'eu-west-1'
      siteIndex: 'index.html'
      siteError: 'error.html'
      targetDir: 'spec/data'
      createAwsClient: @mockAws
    , (err) =>
      should.not.exist err
      @expects.should.have.length 0
      done()





  it 'prints stuff if a stream is given', (done) ->

    output = stringstream.createStream()

    deploy
      s3bucket: 'mybucket.leanmachine.se'
      aws_key: 'awskey'
      aws_secret: 'awssecret'
      aws_user: 'myawsuser'
      region: 'eu-west-1'
      siteIndex: 'index.html'
      siteError: 'error.html'
      targetDir: 'spec/data'
      output: output
      createAwsClient: @mockAws
    , (err) =>
      should.not.exist err
      output.toString().length.should.be.above 100
      done()
