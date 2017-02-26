------------------------------------------------------------------------
--[[ NetworkSaver ]]--
-- Observer.
-- Saves version of the subject with the lowest error and terminates
-- the experiment when no new minima is found for max_epochs.
-- Should only be called on Experiment, Propagator or Model subjects.
------------------------------------------------------------------------
local NetworkSaver, parent = torch.class("dp.NetworkSaver", "dp.ErrorMinima")
NetworkSaver.isNetworkSaver = true

function NetworkSaver:__init(config)
   assert(type(config) == 'table', "Constructor requires key-value arguments")
   local args
   args, save_dir, self._max_epochs, self._max_error,
      self._min_epoch = xlua.unpack(
      {config},
      'NetworkSaver',
      'Saves a model at each new minima of error. ' ..
      'Error can be obtained from experiment report or mediator ' ..
      'channel. If obtained from experiment report via error_report, ' ..
      'subscribes to doneEpoch channel.',
      {arg='save_dir', type='string', help='defaults to dp.SAVE_DIR'},
      {arg='max_epochs', type='number', default=30,
       help='maximum number of epochs to consider after a minima ' ..
       'has been found. After that, a terminate signal is published ' ..
       'to the mediator.'},
      {arg='max_error', type='number', default=0,
       help='maximum value for which the experiment should be ' ..
       'stopped after min_epochs. ' ..
       'If maximize is true, this is min value'},
      {arg='min_epoch', type='number', default=10000000,
       help='see max_error'}
   )
   parent.__init(self, config)

   self._save_dir = save_dir or dp.SAVE_DIR
   self._max_error = self._max_error * self._sign
end

function NetworkSaver:setup(config)
   parent.setup(self, config)
   os.execute('mkdir -p ' .. self._save_dir)
end

function NetworkSaver:compareError(current_error, ...)
   if self._epoch >= self._min_epoch and (self._max_error ~= 0)
         and current_error*self._sign > self._max_error then
      dp.vprint(self._verbose, "NetworkSaver ending experiment. Error too high" )
      self._mediator:publish("doneExperiment")
   end


  self._best_error = self._best_error or current_error -- initialize


   local found_minima = parent.compareError(self, current_error, ...)

--    if self._epoch == 1 then
--      torch.save(paths.concat(self._save_dir,"first_epoch.dat"), self._subject)
--    end

--    torch.save(paths.concat(self._save_dir,"last_epoch.dat"), self._subject)

    if self._maximize and current_error >= self._best_error then
      torch.save(paths.concat(self._save_dir,"best_epoch.dat"), self._subject)
      self._best_error = math.max(current_error, self._best_error) -- update
   elseif not self._maximize and current_error <= self._best_error then
       torch.save(paths.concat(self._save_dir,"best_epoch.dat"), self._subject)
       self._best_error = math.min(current_error, self._best_error) -- update
    end

   if self._max_epochs > 0 and self._max_epochs < (self._epoch - self._minima_epoch) then
      if self._maximize and self._verbose then
         print("found maxima : " .. self._minima*self._sign .. " at epoch " .. self._minima_epoch)
      elseif self._verbose then
         print("found minima : " .. self._minima .. " at epoch " .. self._minima_epoch)
      end
      self._mediator:publish("doneExperiment")
   end
   return found_minima
end

function NetworkSaver:verbose(verbose)
   parent.verbose(self, verbose)
   self._save_strategy:verbose(self._verbose)
end
